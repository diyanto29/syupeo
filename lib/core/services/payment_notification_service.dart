import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/services/payment_gateway_background_helper.dart';
import 'package:dpos/core/services/soundbox_tts_service.dart';
import 'package:dpos/core/supabase/supabase_service.dart';
import 'payment_notification_models.dart';

const String _kSettingsPrefKey = 'dpos_payment_notif_settings';

/// Service untuk parsing teks notifikasi e-wallet & bank
class PaymentNotificationParser {
  /// Ekstrak nominal uang dari teks notifikasi
  /// Contoh: "Kamu menerima saldo sebesar Rp 25.000 dari..." -> 25000.0
  static double? extractAmount(String text) {
    if (text.isEmpty) return null;

    // Bersihkan karakter non-standar namun pertahankan titik/koma dan angka
    // Pola 1: Rp 15.000 / Rp15.000 / Rp. 15.000,00
    final rpRegex = RegExp(
      r'(?:rp\.?|idr)\s*([\d\.\,]+)',
      caseSensitive: false,
    );
    final rpMatch = rpRegex.firstMatch(text);
    if (rpMatch != null) {
      final rawNum = rpMatch.group(1);
      if (rawNum != null) {
        final parsed = _parseCleanNumber(rawNum);
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    // Pola 2: Berhasil transfer sebesar 50.000 atau terima 50.000
    final numRegex = RegExp(
      r'(?:sebesar|masuk|terima|diterima|nominal)\s*([\d\.\,]+)',
      caseSensitive: false,
    );
    final numMatch = numRegex.firstMatch(text);
    if (numMatch != null) {
      final rawNum = numMatch.group(1);
      if (rawNum != null) {
        final parsed = _parseCleanNumber(rawNum);
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    return null;
  }

  /// Ekstrak nama / asal pengirim uang dari teks notifikasi jika ada
  /// Contoh: "Kamu menerima transfer dari BUDI SANTOSO" -> "BUDI SANTOSO"
  /// Contoh: "DANA: Uang masuk Rp 50.000 dari SITI AMINAH" -> "SITI AMINAH"
  /// Contoh: "TRSF CR DARI AHMAD FAUZI RP 100.000" -> "AHMAD FAUZI"
  static String? extractSender(String text) {
    if (text.isEmpty) return null;

    // Pola 1: "dari [Nama Pengirim] sebesar..." atau "dari [Nama Pengirim]"
    final fromRegex = RegExp(
      r"(?:dari|from)\s+([A-Za-z0-9\s\.\,\'-]{2,35})",
      caseSensitive: false,
    );
    final match = fromRegex.firstMatch(text);
    if (match != null) {
      final candidate = match.group(1)?.trim();
      if (candidate != null &&
          candidate.length >= 2 &&
          !RegExp(
            r'^(?:rp|idr|\d+)$',
            caseSensitive: false,
          ).hasMatch(candidate)) {
        return _cleanSenderName(candidate);
      }
    }

    // Pola 2: Format mutasi bank e.g. "TRSF CR 50000 DARI JOHN DOE"
    final bankRegex = RegExp(
      r'(?:dr|dari)\s+([A-Z0-9\s]{3,30})',
      caseSensitive: false,
    );
    final bankMatch = bankRegex.firstMatch(text);
    if (bankMatch != null) {
      final candidate = bankMatch.group(1)?.trim();
      if (candidate != null && candidate.length >= 2) {
        return _cleanSenderName(candidate);
      }
    }

    return null;
  }

  /// Ekstrak nama cabang / outlet jika tercantum di judul atau teks notifikasi
  /// Contoh: "GoBiz - Outlet Tebet: Kamu menerima..." -> "Tebet"
  /// Contoh: "GoBiz - Cabang Pasar Baru: Kamu menerima..." -> "Pasar Baru"
  static String? extractOutletName(String title, String content) {
    final text = '$title $content';
    final branchRegex = RegExp(
      r'(?:outlet|cabang|gerai|store|toko)\s+([A-Za-z0-9\s]{2,25})',
      caseSensitive: false,
    );
    final match = branchRegex.firstMatch(text);
    if (match != null) {
      final name = match.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        return name.replaceAll(RegExp(r'[\:\,\.\-]+$'), '').trim();
      }
    }

    final parenRegex = RegExp(r'\(([^)]+)\)');
    final parenMatch = parenRegex.firstMatch(title);
    if (parenMatch != null) {
      final name = parenMatch.group(1)?.trim();
      if (name != null && name.length >= 3) {
        return name;
      }
    }

    return null;
  }

  static String _cleanSenderName(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'[\.\,\:\;]+$'), '').trim();
    cleaned = cleaned
        .replaceAll(
          RegExp(r'\s+(sebesar|ke|rp|idr)$', caseSensitive: false),
          '',
        )
        .trim();
    return cleaned;
  }

  /// Mengecek apakah teks notifikasi mengindikasikan uang MASUK / berhasil diterima
  static bool isIncomingPayment(String title, String content, [String? packageName]) {
    final combined = '$title $content'.toLowerCase();
    final pkg = packageName?.toLowerCase() ?? '';

    // Aplikasi khusus merchant (Livin' Merchant, GoBiz, BCA Merchant)
    // Semua notifikasi transaksi di aplikasi ini adalah uang MASUK (penjualan)
    final isMerchantApp = pkg == 'id.bmri.livinmerchant' ||
        pkg == 'com.gojek.merchant' ||
        pkg == 'com.bca.merchant' ||
        pkg == 'com.grab.merchant' ||
        combined.contains('livin merchant') ||
        combined.contains('livinmerchant') ||
        combined.contains('gobiz');

    // Kata kunci penolak (uang keluar / promo / gagal)
    final ignoreWords = [
      'berhasil bayar',
      'kamu telah membayar',
      'pembayaran berhasil dilakukan',
      'promo',
      'diskon',
      'voucher',
      'cashback kamu',
      'gagal',
      'dibatalkan',
      'pulsa berhasil',
      'token pln',
    ];

    for (final neg in ignoreWords) {
      if (combined.contains(neg)) return false;
    }

    if (isMerchantApp) {
      // Di aplikasi merchant, kata 'berhasil' atau 'transaksi' atau 'terima' sudah pasti uang masuk
      final merchantPositive = [
        'berhasil',
        'transaksi',
        'pembayaran',
        'qris',
        'masuk',
        'terima',
        'diterima',
        'dana',
        'saldo',
      ];
      for (final pos in merchantPositive) {
        if (combined.contains(pos)) return true;
      }
    }

    // Kata kunci penerimaan uang masuk standar perbankan / e-wallet
    final incomingWords = [
      'menerima saldo',
      'kamu menerima',
      'transfer masuk',
      'dana masuk',
      'uang masuk',
      'berhasil ditambahkan',
      'telah diterima',
      'dapat transferan',
      'terima saldo',
      'top up berhasil',
      'qris berhasil',
      'pembayaran qris masuk',
      'pembayaran berhasil',
      'transaksi berhasil',
      'berhasil diterima',
      'transaksi masuk',
      'qris masuk',
      'penerimaan qris',
      'payment received',
      'cr ', // Credit BCA/Mandiri e.g. "TRSF CR 50,000"
      'cr/',
      'masuk ke rekening',
    ];

    for (final pos in incomingWords) {
      if (combined.contains(pos)) return true;
    }

    return false;
  }

  static double? _parseCleanNumber(String raw) {
    var cleaned = raw.trim();

    while (cleaned.endsWith('.') || cleaned.endsWith(',')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }

    // Format Indonesia standar ribuan titik, sen koma: "25.000,00" atau "25.000"
    if (cleaned.contains('.') && cleaned.contains(',')) {
      cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
    } else if (cleaned.contains('.')) {
      final parts = cleaned.split('.');
      if (parts.length > 2) {
        cleaned = cleaned.replaceAll('.', '');
      } else if (parts.last.length == 3) {
        cleaned = cleaned.replaceAll('.', '');
      }
    } else if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts.last.length == 3) {
        cleaned = cleaned.replaceAll(',', '');
      } else {
        cleaned = cleaned.replaceAll(',', '.');
      }
    }

    return double.tryParse(cleaned);
  }
}

/// Controller / State Notifier untuk Notification Payment Listener & Soundbox Relay
class PaymentNotificationNotifier
    extends StateNotifier<AsyncValue<NotificationPaymentSettings>> {
  final Ref _ref;

  PaymentNotificationNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  StreamSubscription<ServiceNotificationEvent>? _subscription;
  RealtimeChannel? _realtimeChannel;
  String? _currentBusinessId;
  String? _currentOutletName;

  final _eventStreamController =
      StreamController<DetectedPaymentEvent>.broadcast();

  Stream<DetectedPaymentEvent> get paymentEvents =>
      _eventStreamController.stream;

  final List<DetectedPaymentEvent> _recentQueue = [];
  List<DetectedPaymentEvent> get recentQueue => List.unmodifiable(_recentQueue);

  DetectedPaymentEvent? _latestDetected;
  DetectedPaymentEvent? get latestDetected => _latestDetected;

  void dismissPayment(String id) {
    _recentQueue.removeWhere((p) => p.id == id);
    if (_latestDetected?.id == id) {
      _latestDetected = _recentQueue.isNotEmpty ? _recentQueue.last : null;
    }
  }

  void markAsUsed(String id) {
    dismissPayment(id);
    markAsConsumedInCloud(id);
  }

  void _pruneOldQueue() {
    final now = DateTime.now();
    _recentQueue.removeWhere(
      (p) => now.difference(p.timestamp).inMinutes >= 10,
    );
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_kSettingsPrefKey);

      NotificationPaymentSettings settings;
      if (savedStr != null) {
        settings = NotificationPaymentSettings.fromJson(savedStr);
      } else {
        settings = NotificationPaymentSettings();
      }

      state = AsyncValue.data(settings);

      // Sinkronkan bootstrap bisnis untuk Supabase Realtime channel
      _initBootstrapSync();

      if (settings.isEnabled) {
        _applyRoleListening(settings);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _initBootstrapSync() {
    final bootstrap = _ref.read(homeBootstrapProvider).valueOrNull;
    if (bootstrap?.business?.id != null) {
      _currentBusinessId = bootstrap!.business!.id;
      _currentOutletName = bootstrap.currentOutlet?.name;
      _setupRealtimeRelay();
    }

    _ref.listen(homeBootstrapProvider, (prev, next) {
      final b = next.valueOrNull;
      if (b?.business?.id != null && b!.business!.id != _currentBusinessId) {
        _currentBusinessId = b.business!.id;
        _currentOutletName = b.currentOutlet?.name;
        _setupRealtimeRelay();
      }
    });
  }

  /// Konfigurasi Supabase Realtime Broadcast & Postgres Changes untuk relay pembayaran
  void _setupRealtimeRelay() {
    if (!SupabaseService.isConfigured || _currentBusinessId == null) return;
    _realtimeChannel?.unsubscribe();

    final channelName = 'payment_relay:$_currentBusinessId';
    _realtimeChannel = SupabaseService.client
        .channel(
          channelName,
          opts: const RealtimeChannelConfig(self: false),
        )
        .onBroadcast(
          event: 'payment_received',
          callback: (payload) {
            _onCloudRelayEvent(payload);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'payment_relay_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'business_id',
            value: _currentBusinessId!,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty && newRecord['is_consumed'] != true) {
              _onCloudRelayEvent(newRecord);
            }
          },
        )
        .subscribe();

    debugPrint('⚡ [PaymentRelay] Subscribed to Realtime channel: $channelName');
  }

  /// Menangani event relay pembayaran dari cloud (HP Owner -> HP Kasir)
  void _onCloudRelayEvent(Map<String, dynamic> payload) {
    final currentSettings = state.value;
    // Jika perangkat ini bertindak HANYA sebagai Gateway Owner, jangan proses balik agar tidak duplikat
    if (currentSettings?.role == DevicePaymentRole.gatewayOwner) return;

    final event = DetectedPaymentEvent.fromMap(payload);
    if (event.amount <= 0) return;

    // Cek duplikasi event
    if (_recentQueue.any((p) => p.id == event.id)) return;

    // Jika notifikasi menyertakan nama cabang spesifik dan beda dengan cabang ini, abaikan
    if (event.detectedOutletName != null &&
        _currentOutletName != null &&
        event.detectedOutletName!.trim().isNotEmpty) {
      final eventBranch = event.detectedOutletName!.toLowerCase();
      final myBranch = _currentOutletName!.toLowerCase();
      if (!myBranch.contains(eventBranch) && !eventBranch.contains(myBranch)) {
        debugPrint(
          '[PaymentRelay] Event for other outlet (${event.detectedOutletName}) ignored on $_currentOutletName',
        );
        return;
      }
    }

    _pruneOldQueue();
    _recentQueue.add(event);
    _latestDetected = event;
    _eventStreamController.add(event);

    // Suarakan TTS Soundbox jika diaktifkan
    if (currentSettings?.enableTtsSoundbox == true) {
      _ref.read(soundboxTtsServiceProvider).speakPayment(
            appName: event.appName,
            amount: event.amount.round(),
            sender: event.sender,
            speechRate: currentSettings?.ttsSpeechRate,
          );
    }

    debugPrint(
      '🔔 [PaymentRelay CLOUD]: ${event.appName} -> Rp ${event.amount} received (TTS played)',
    );
  }

  /// Broadcast event lokal ke cloud (HP Owner -> Cloud)
  Future<void> _broadcastToCloud(DetectedPaymentEvent event) async {
    if (!SupabaseService.isConfigured || _currentBusinessId == null) {
      debugPrint('[PaymentRelay] Cannot broadcast: not configured or businessId is null');
      return;
    }

    try {
      // 1. Simpan ke database Supabase agar persisten (anti hilang jika kasir terlambat buka QR)
      await SupabaseService.client.from('payment_relay_events').insert({
        'id': event.id,
        'business_id': _currentBusinessId,
        'amount': event.amount,
        'app_name': event.appName,
        'sender': event.sender,
        'raw_title': event.rawTitle,
        'raw_content': event.rawContent,
        'detected_outlet_name': event.detectedOutletName,
        'is_consumed': false,
      });

      // 2. Broadcast instan via WebSocket channel jika tersambung
      if (_realtimeChannel != null) {
        await _realtimeChannel!.sendBroadcastMessage(
          event: 'payment_received',
          payload: event.toMap(),
        );
      }
      debugPrint(
        '🚀 [PaymentRelay CLOUD]: Saved & broadcasted to $_currentBusinessId (Rp ${event.amount})',
      );
    } catch (e) {
      debugPrint('[PaymentRelay] Broadcast exception: $e');
    }
  }

  /// Mencari pembayaran masuk yang belum dikonsumsi dari cloud (anti-terlewat jika pelanggan bayar sebelum kasir buka QR)
  Future<DetectedPaymentEvent?> checkExistingUnconsumedPayment(
    double amount,
  ) async {
    if (!SupabaseService.isConfigured || _currentBusinessId == null) return null;

    try {
      final twoMinutesAgo = DateTime.now()
          .subtract(const Duration(minutes: 2))
          .toUtc()
          .toIso8601String();

      final res = await SupabaseService.client
          .from('payment_relay_events')
          .select()
          .eq('business_id', _currentBusinessId!)
          .eq('amount', amount)
          .eq('is_consumed', false)
          .gte('created_at', twoMinutesAgo)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res != null) {
        final event = DetectedPaymentEvent.fromMap(res);

        // Tandai langsung di cloud agar tidak dipakai transaksi lain
        await markAsConsumedInCloud(event.id);

        if (!_recentQueue.any((p) => p.id == event.id)) {
          _recentQueue.add(event);
        }
        _latestDetected = event;
        _eventStreamController.add(event);
        return event;
      }
    } catch (e) {
      debugPrint('[PaymentRelay] checkExistingUnconsumedPayment error: $e');
    }
    return null;
  }

  /// Menandai pembayaran di cloud sudah dikonsumsi oleh kasir
  Future<void> markAsConsumedInCloud(String eventId) async {
    if (!SupabaseService.isConfigured) return;
    try {
      await SupabaseService.client.from('payment_relay_events').update({
        'is_consumed': true,
        'consumed_at': DateTime.now().toUtc().toIso8601String(),
        'consumed_by': SupabaseService.client.auth.currentUser?.id,
      }).eq('id', eventId);
    } catch (e) {
      debugPrint('[PaymentRelay] markAsConsumedInCloud error: $e');
    }
  }

  /// Cek apakah izin notifikasi Android sudah aktif
  Future<bool> checkPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await NotificationListenerService.isPermissionGranted();
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      return false;
    }
  }

  /// Buka menu pengaturan Android agar user dapat memberikan izin Notification Access
  Future<bool> requestPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await NotificationListenerService.requestPermission();
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      return false;
    }
  }

  /// Simpan pengaturan baru
  Future<void> updateSettings(NotificationPaymentSettings newSettings) async {
    state = AsyncValue.data(newSettings);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSettingsPrefKey, newSettings.toJson());

    if (newSettings.isEnabled) {
      _applyRoleListening(newSettings);
    } else {
      _stopListening();
    }
  }

  void _applyRoleListening(NotificationPaymentSettings settings) {
    if (settings.role == DevicePaymentRole.cashierOnly) {
      // Kasir tidak perlu mendengarkan notifikasi lokal Android HP ini
      _stopListening();
      PaymentGatewayBackgroundHelper.stopGatewayService();
    } else {
      // Gateway Owner atau Both perlu listener notifikasi Android
      _startListening();
      if (settings.isEnabled && settings.isForegroundServiceEnabled) {
        PaymentGatewayBackgroundHelper.startGatewayService();
      } else {
        PaymentGatewayBackgroundHelper.stopGatewayService();
      }
    }
  }

  /// Toggle on/off master
  Future<void> setEnabled(bool enabled) async {
    final current = state.value ?? NotificationPaymentSettings();
    await updateSettings(current.copyWith(isEnabled: enabled));
  }

  /// Ubah peran perangkat (Kasir / Gateway Owner / Keduanya)
  Future<void> setRole(DevicePaymentRole role) async {
    final current = state.value ?? NotificationPaymentSettings();
    await updateSettings(current.copyWith(role: role));
  }

  /// Toggle on/off layanan latar belakang 24/7 di status bar
  Future<void> toggleForegroundService(bool enable) async {
    final current = state.value ?? NotificationPaymentSettings();
    await updateSettings(current.copyWith(isForegroundServiceEnabled: enable));
  }

  /// Toggle on/off suara Text-to-Speech Soundbox
  Future<void> setEnableTtsSoundbox(bool enable) async {
    final current = state.value ?? NotificationPaymentSettings();
    await updateSettings(current.copyWith(enableTtsSoundbox: enable));
  }

  /// Ubah kecepatan bicara TTS (0.35 - 0.70)
  Future<void> setTtsSpeechRate(double rate) async {
    final current = state.value ?? NotificationPaymentSettings();
    await updateSettings(current.copyWith(ttsSpeechRate: rate));
  }

  /// Toggle on/off per aplikasi (package name)
  Future<void> togglePackage(String packageName, bool enabled) async {
    final current = state.value ?? NotificationPaymentSettings();
    final updatedSet = Set<String>.from(current.enabledPackageNames);
    if (enabled) {
      updatedSet.add(packageName);
    } else {
      updatedSet.remove(packageName);
    }
    await updateSettings(current.copyWith(enabledPackageNames: updatedSet));
  }

  /// Toggle mode auto confirm
  Future<void> setAutoConfirm(bool autoConfirm) async {
    final current = state.value ?? NotificationPaymentSettings();
    await updateSettings(current.copyWith(autoConfirmExactMatch: autoConfirm));
  }

  /// Nyalakan listener stream lokal Android
  void _startListening() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _subscription?.cancel();
    try {
      _subscription = NotificationListenerService.notificationsStream.listen(
        _onIncomingEvent,
      );
    } catch (e) {
      debugPrint('NotificationListenerService listen warning: $e');
    }
  }

  /// Matikan listener stream lokal
  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    PaymentGatewayBackgroundHelper.stopGatewayService();
  }

  /// Tangani notifikasi Android lokal yang masuk di perangkat ini
  void _onIncomingEvent(ServiceNotificationEvent event) {
    final currentSettings = state.value;
    if (currentSettings == null || !currentSettings.isEnabled) return;
    if (currentSettings.role == DevicePaymentRole.cashierOnly) return;

    final packageName = event.packageName;
    if (packageName.isEmpty) return;

    final isAllowed = currentSettings.enabledPackageNames.any(
      (pkg) =>
          packageName.toLowerCase().contains(pkg.toLowerCase()) ||
          pkg.toLowerCase().contains(packageName.toLowerCase()),
    );

    if (!isAllowed) return;

    final title = event.title;
    final content = event.content;

    if (!PaymentNotificationParser.isIncomingPayment(
        title, content, packageName)) {
      return;
    }

    final amount = PaymentNotificationParser.extractAmount('$title $content');
    if (amount == null || amount <= 0) {
      return;
    }

    final matchedApp = PaymentAppCatalog.findByPackage(packageName);
    final appName = matchedApp?.name ?? packageName;
    final sender = PaymentNotificationParser.extractSender('$title $content');
    final detectedBranch =
        PaymentNotificationParser.extractOutletName(title, content);

    final paymentEvent = DetectedPaymentEvent(
      id: const Uuid().v4(),
      appName: appName,
      packageName: packageName,
      amount: amount,
      sender: sender,
      detectedOutletName: detectedBranch,
      rawTitle: title,
      rawContent: content,
      timestamp: DateTime.now(),
      isFromCloud: false,
    );

    _pruneOldQueue();
    final isDuplicate = _recentQueue.any(
      (p) =>
          p.packageName == paymentEvent.packageName &&
          p.amount == paymentEvent.amount &&
          paymentEvent.timestamp.difference(p.timestamp).inSeconds.abs() < 10,
    );
    if (!isDuplicate) {
      _recentQueue.add(paymentEvent);
    }

    _latestDetected = paymentEvent;
    _eventStreamController.add(paymentEvent);

    // 1. Broadcast ke Supabase Realtime untuk kasir lain di bisnis ini
    _broadcastToCloud(paymentEvent);

    // 2. Jika perangkat ini juga bertindak sebagai kasir (mode both), bunyikan TTS
    if (currentSettings.role == DevicePaymentRole.both &&
        currentSettings.enableTtsSoundbox) {
      _ref.read(soundboxTtsServiceProvider).speakPayment(
            appName: paymentEvent.appName,
            amount: paymentEvent.amount.round(),
            sender: paymentEvent.sender,
            speechRate: currentSettings.ttsSpeechRate,
          );
    }

    debugPrint(
      '🔔 [DPOS AUTO PAYMENT DETECTED LOKAL]: ${paymentEvent.appName} -> Rp ${paymentEvent.amount}',
    );
  }

  void markLatestAsHandled() {
    if (_latestDetected != null) {
      dismissPayment(_latestDetected!.id);
    }
    _latestDetected = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _realtimeChannel?.unsubscribe();
    _eventStreamController.close();
    super.dispose();
  }
}

/// Riverpod Provider untuk akses layanan notifikasi pembayaran di seluruh aplikasi
final paymentNotificationProvider = StateNotifierProvider<
    PaymentNotificationNotifier, AsyncValue<NotificationPaymentSettings>>((ref) {
  return PaymentNotificationNotifier(ref);
});

/// Provider stream event pembayaran masuk terbaru
final incomingPaymentStreamProvider = StreamProvider<DetectedPaymentEvent>((
  ref,
) {
  final notifier = ref.watch(paymentNotificationProvider.notifier);
  return notifier.paymentEvents;
});
