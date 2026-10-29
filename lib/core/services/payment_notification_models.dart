import 'dart:convert';

/// Peran perangkat dalam ekosistem pembayaran DPOS
enum DevicePaymentRole {
  /// Mode Kasir: Menerima relay pembayaran dari cloud dan membunyikan TTS Soundbox
  cashierOnly,

  /// Mode Hook Gateway: Berjalan di HP Owner / HP yang terpasang GoBiz/Livin untuk relay ke kasir
  gatewayOwner,

  /// Mode Mandiri: Kasir & GoBiz terpasang di HP yang sama
  both;

  String get label {
    switch (this) {
      case DevicePaymentRole.cashierOnly:
        return 'Mode Kasir (Penerima & Soundbox)';
      case DevicePaymentRole.gatewayOwner:
        return 'Mode Hook Gateway (HP Owner / Merchant)';
      case DevicePaymentRole.both:
        return 'Mode Mandiri (Kasir & Merchant di HP ini)';
    }
  }

  String get description {
    switch (this) {
      case DevicePaymentRole.cashierOnly:
        return 'Menerima konfirmasi otomatis dari HP Owner via cloud dan menyuarakan pengumuman TTS.';
      case DevicePaymentRole.gatewayOwner:
        return 'Membaca notifikasi GoBiz / Livin / Bank di HP ini lalu meneruskannya secara realtime ke HP kasir.';
      case DevicePaymentRole.both:
        return 'HP ini menjalankan kasir sekaligus menerima notifikasi e-wallet secara langsung.';
    }
  }
}

/// Model untuk konfigurasi e-wallet / bank yang didukung
class SupportedPaymentApp {
  final String id;
  final String name;
  final String packageName;
  final String defaultMethodCode; // Cocokkan dengan metode POS jika ada (qris / transfer)
  final String iconAsset;

  const SupportedPaymentApp({
    required this.id,
    required this.name,
    required this.packageName,
    this.defaultMethodCode = 'qris',
    this.iconAsset = '',
  });
}

/// Daftar aplikasi e-wallet & m-banking populer di Indonesia
class PaymentAppCatalog {
  static const List<SupportedPaymentApp> allApps = [
    SupportedPaymentApp(
      id: 'gobiz',
      name: 'GoBiz (GoPay Merchant)',
      packageName: 'com.gojek.merchant',
      defaultMethodCode: 'qris',
    ),
    SupportedPaymentApp(
      id: 'gopay',
      name: 'GoPay / Gojek',
      packageName: 'com.gojek.app',
      defaultMethodCode: 'qris',
    ),
    SupportedPaymentApp(
      id: 'livin_merchant',
      name: 'Livin\' Merchant (Bank Mandiri)',
      packageName: 'id.bmri.livinmerchant',
      defaultMethodCode: 'qris',
    ),
    SupportedPaymentApp(
      id: 'livin_usaha',
      name: 'Livin\' Usaha (Mandiri)',
      packageName: 'id.co.mandiri.livin.usaha',
      defaultMethodCode: 'qris',
    ),
    SupportedPaymentApp(
      id: 'livin',
      name: 'Livin\' by Mandiri',
      packageName: 'id.co.mandiri.livin',
      defaultMethodCode: 'transfer',
    ),
    SupportedPaymentApp(
      id: 'bca_merchant',
      name: 'Merchant BCA',
      packageName: 'com.bca.merchant',
      defaultMethodCode: 'qris',
    ),
    SupportedPaymentApp(
      id: 'bca',
      name: 'BCA Mobile / myBCA',
      packageName: 'com.bca',
      defaultMethodCode: 'transfer',
    ),
    SupportedPaymentApp(
      id: 'dana',
      name: 'DANA Bisnis / DANA',
      packageName: 'id.dana',
      defaultMethodCode: 'qris',
    ),
    SupportedPaymentApp(
      id: 'shopeepay',
      name: 'Shopee / ShopeePay',
      packageName: 'com.shopee.id',
      defaultMethodCode: 'qris',
    ),
    SupportedPaymentApp(
      id: 'ovo',
      name: 'OVO / OVO Merchant',
      packageName: 'ovo.id',
      defaultMethodCode: 'qris',
    ),
    SupportedPaymentApp(
      id: 'grab_merchant',
      name: 'GrabMerchant',
      packageName: 'com.grab.merchant',
      defaultMethodCode: 'qris',
    ),
    SupportedPaymentApp(
      id: 'brimo',
      name: 'BRImo (Bank BRI)',
      packageName: 'id.co.bri.brimo',
      defaultMethodCode: 'transfer',
    ),
    SupportedPaymentApp(
      id: 'bni',
      name: 'BNI Mobile Banking',
      packageName: 'src.com.bni',
      defaultMethodCode: 'transfer',
    ),
    SupportedPaymentApp(
      id: 'seabank',
      name: 'SeaBank',
      packageName: 'com.seabank.id',
      defaultMethodCode: 'transfer',
    ),
  ];

  static SupportedPaymentApp? findByPackage(String? packageName) {
    if (packageName == null) return null;
    final lower = packageName.toLowerCase();
    for (final app in allApps) {
      if (lower.contains(app.packageName.toLowerCase()) ||
          app.packageName.toLowerCase().contains(lower)) {
        return app;
      }
    }
    return null;
  }
}

/// Model objek event pembayaran yang berhasil dideteksi dari notifikasi atau cloud relay
class DetectedPaymentEvent {
  final String id;
  final String appName;
  final String packageName;
  final double amount;
  final String? sender; // Nama / info pengirim transfer jika terdeteksi
  final String? detectedOutletName; // Nama cabang jika tertera di notifikasi
  final String? rawTitle;
  final String? rawContent;
  final DateTime timestamp;
  final bool isMatched;
  final bool isFromCloud;

  DetectedPaymentEvent({
    required this.id,
    required this.appName,
    required this.packageName,
    required this.amount,
    this.sender,
    this.detectedOutletName,
    this.rawTitle,
    this.rawContent,
    required this.timestamp,
    this.isMatched = false,
    this.isFromCloud = false,
  });

  DetectedPaymentEvent copyWith({
    String? sender,
    String? detectedOutletName,
    bool? isMatched,
    bool? isFromCloud,
  }) {
    return DetectedPaymentEvent(
      id: id,
      appName: appName,
      packageName: packageName,
      amount: amount,
      sender: sender ?? this.sender,
      detectedOutletName: detectedOutletName ?? this.detectedOutletName,
      rawTitle: rawTitle,
      rawContent: rawContent,
      timestamp: timestamp,
      isMatched: isMatched ?? this.isMatched,
      isFromCloud: isFromCloud ?? this.isFromCloud,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'app_name': appName,
      'package_name': packageName,
      'amount': amount,
      'sender': sender,
      'detected_outlet_name': detectedOutletName,
      'raw_title': rawTitle,
      'raw_content': rawContent,
      'timestamp': timestamp.toIso8601String(),
      'is_matched': isMatched,
      'is_from_cloud': isFromCloud,
    };
  }

  factory DetectedPaymentEvent.fromMap(Map<String, dynamic> map) {
    DateTime parsedTime = DateTime.now();
    if (map['timestamp'] != null) {
      parsedTime =
          DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now();
    } else if (map['created_at'] != null) {
      parsedTime =
          DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now();
    }

    return DetectedPaymentEvent(
      id: map['id']?.toString() ?? '',
      appName: map['app_name']?.toString() ?? 'QRIS',
      packageName: map['package_name']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      sender: map['sender']?.toString(),
      detectedOutletName: map['detected_outlet_name']?.toString(),
      rawTitle: map['raw_title']?.toString(),
      rawContent: map['raw_content']?.toString(),
      timestamp: parsedTime,
      isMatched: map['is_matched'] as bool? ?? false,
      isFromCloud: true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DetectedPaymentEvent.fromJson(String source) =>
      DetectedPaymentEvent.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// Pengaturan konfigurasi pembacaan notifikasi & Soundbox TTS
class NotificationPaymentSettings {
  final bool isEnabled;
  final bool autoConfirmExactMatch; // Jika true & nominal pas dengan total belanja, langsung checkout
  final DevicePaymentRole role;
  final bool enableTtsSoundbox; // Suarakan Text-to-Speech saat pembayaran berhasil
  final double ttsSpeechRate; // Kecepatan suara TTS (0.35 - 0.70)
  final bool isForegroundServiceEnabled; // Layanan foreground 24/7 di status bar
  final Set<String> enabledPackageNames;

  NotificationPaymentSettings({
    this.isEnabled = false,
    this.autoConfirmExactMatch = true,
    this.role = DevicePaymentRole.both,
    this.enableTtsSoundbox = true,
    this.ttsSpeechRate = 0.48,
    this.isForegroundServiceEnabled = true,
    Set<String>? enabledPackageNames,
  }) : enabledPackageNames = enabledPackageNames ??
            PaymentAppCatalog.allApps.map((e) => e.packageName).toSet();

  NotificationPaymentSettings copyWith({
    bool? isEnabled,
    bool? autoConfirmExactMatch,
    DevicePaymentRole? role,
    bool? enableTtsSoundbox,
    double? ttsSpeechRate,
    bool? isForegroundServiceEnabled,
    Set<String>? enabledPackageNames,
  }) {
    return NotificationPaymentSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      autoConfirmExactMatch:
          autoConfirmExactMatch ?? this.autoConfirmExactMatch,
      role: role ?? this.role,
      enableTtsSoundbox: enableTtsSoundbox ?? this.enableTtsSoundbox,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
      isForegroundServiceEnabled:
          isForegroundServiceEnabled ?? this.isForegroundServiceEnabled,
      enabledPackageNames: enabledPackageNames ?? this.enabledPackageNames,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'autoConfirmExactMatch': autoConfirmExactMatch,
      'role': role.name,
      'enableTtsSoundbox': enableTtsSoundbox,
      'ttsSpeechRate': ttsSpeechRate,
      'isForegroundServiceEnabled': isForegroundServiceEnabled,
      'enabledPackageNames': enabledPackageNames.toList(),
    };
  }

  factory NotificationPaymentSettings.fromMap(Map<String, dynamic> map) {
    DevicePaymentRole parsedRole = DevicePaymentRole.both;
    if (map['role'] != null) {
      try {
        parsedRole = DevicePaymentRole.values.byName(map['role'].toString());
      } catch (_) {}
    }

    final savedPackages = (map['enabledPackageNames'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        PaymentAppCatalog.allApps.map((e) => e.packageName).toSet();
    savedPackages.addAll([
      'id.bmri.livinmerchant',
      'com.gojek.merchant',
      'com.bca.merchant',
    ]);

    double parsedSpeechRate = (map['ttsSpeechRate'] as num?)?.toDouble() ?? 0.48;
    if (parsedSpeechRate > 0.70) {
      parsedSpeechRate = 0.48; // Migrasi otomatis jika kecepatan sebelumnya terlalu tinggi (0.82)
    }

    return NotificationPaymentSettings(
      isEnabled: map['isEnabled'] as bool? ?? false,
      autoConfirmExactMatch: map['autoConfirmExactMatch'] as bool? ?? true,
      role: parsedRole,
      enableTtsSoundbox: map['enableTtsSoundbox'] as bool? ?? true,
      ttsSpeechRate: parsedSpeechRate,
      isForegroundServiceEnabled:
          map['isForegroundServiceEnabled'] as bool? ?? true,
      enabledPackageNames: savedPackages,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory NotificationPaymentSettings.fromJson(String source) =>
      NotificationPaymentSettings.fromMap(
          jsonDecode(source) as Map<String, dynamic>);
}
