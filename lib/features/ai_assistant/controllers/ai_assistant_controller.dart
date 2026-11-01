import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dpos/core/providers/bootstrap_provider.dart';
import 'package:dpos/core/services/gemini_service.dart';
import 'package:dpos/features/ai_assistant/domain/ai_message_model.dart';
import 'package:dpos/features/ai_assistant/services/voice_recognition_service.dart';
import 'package:dpos/features/ai_assistant/services/text_to_speech_service.dart';
import 'package:dpos/features/cash_flow/state/cash_flow_provider.dart';
import 'package:dpos/features/dashboard/presentation/widgets/sales_dashboard_view.dart';
import 'package:dpos/features/menu_management/data/menu_repository.dart';
import 'package:dpos/features/menu_management/domain/menu_models.dart';
import 'package:dpos/features/inventory/presentation/providers/inventory_dashboard_provider.dart';

class AiAssistantState {
  final List<AiMessageModel> messages;
  final bool isLoading;
  final bool isListening;
  final String currentSpokenText;
  final double soundLevel;
  final int recordingDurationSeconds;
  final String? voiceErrorMessage;
  final String? apiKey;
  final String businessName;
  final bool isTtsEnabled;
  final bool isSpeaking;
  final String? currentlySpeakingMsgId;

  const AiAssistantState({
    this.messages = const [],
    this.isLoading = false,
    this.isListening = false,
    this.currentSpokenText = '',
    this.soundLevel = 0.0,
    this.recordingDurationSeconds = 0,
    this.voiceErrorMessage,
    this.apiKey,
    this.businessName = 'Syupeo Store',
    this.isTtsEnabled = true,
    this.isSpeaking = false,
    this.currentlySpeakingMsgId,
  });

  AiAssistantState copyWith({
    List<AiMessageModel>? messages,
    bool? isLoading,
    bool? isListening,
    String? currentSpokenText,
    double? soundLevel,
    int? recordingDurationSeconds,
    String? voiceErrorMessage,
    String? apiKey,
    String? businessName,
    bool? isTtsEnabled,
    bool? isSpeaking,
    String? currentlySpeakingMsgId,
  }) {
    return AiAssistantState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isListening: isListening ?? this.isListening,
      currentSpokenText: currentSpokenText ?? this.currentSpokenText,
      soundLevel: soundLevel ?? this.soundLevel,
      recordingDurationSeconds:
          recordingDurationSeconds ?? this.recordingDurationSeconds,
      voiceErrorMessage: voiceErrorMessage,
      apiKey: apiKey ?? this.apiKey,
      businessName: businessName ?? this.businessName,
      isTtsEnabled: isTtsEnabled ?? this.isTtsEnabled,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      currentlySpeakingMsgId:
          currentlySpeakingMsgId ?? this.currentlySpeakingMsgId,
    );
  }
}

final aiAssistantControllerProvider =
    StateNotifierProvider.autoDispose<AiAssistantController, AiAssistantState>(
        (ref) {
  final gemini = GeminiService();
  final voice = VoiceRecognitionService();
  final tts = TextToSpeechService();
  return AiAssistantController(ref, gemini, voice, tts);
});

class AiAssistantController extends StateNotifier<AiAssistantState> {
  AiAssistantController(
    this._ref,
    this._gemini,
    this._voiceService,
    this._ttsService,
  ) : super(const AiAssistantState()) {
    _init();
  }

  final Ref _ref;
  final GeminiService _gemini;
  final VoiceRecognitionService _voiceService;
  final TextToSpeechService _ttsService;
  Timer? _recordingTimer;

  Future<void> _init() async {
    final key = await _gemini.getApiKey();
    final bootstrap = _ref.read(homeBootstrapProvider).value;
    final bName = bootstrap?.business?.name ?? 'Syupeo Store';

    final welcomeMessage = AiMessageModel(
      id: 'welcome-1',
      content:
          'Halo! Saya **Asisten AI Syupeo** siap membantu operasional dan analitik bisnis **$bName** hari ini.\n\n'
          'Anda bisa bertanya langsung dengan mengetik atau **menekan tombol mikrofon 🎙️**:\n'
          '• 💰 **Laporan & Penjualan:** *"Berapa pendapatan & laba bersih hari ini?"*\n'
          '• 📦 **Katalog & Stok:** *"Ada stok apa yang menipis?"* atau *"Berapa harga produk X?"*\n'
          '• 🏆 **Analitik:** *"Produk apa yang paling laris hari ini?"*\n'
          '• 💡 **Ide Bisnis:** *"Buatkan ide promo bundling hemat untuk hari ini"*\n'
          '• 💵 **Kas Laci:** *"Berapa perkiraan uang kas di laci kasir saat ini?"*',
      isUser: false,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      apiKey: key,
      businessName: bName,
      messages: [welcomeMessage],
    );
  }

  Future<void> saveApiKey(String key) async {
    await _gemini.saveApiKey(key);
    state = state.copyWith(apiKey: key);
  }

  // ── Voice Input Methods ──────────────────────────────────────────

  Future<bool> startVoiceRecording() async {
    _recordingTimer?.cancel();
    state = state.copyWith(
      isListening: true,
      currentSpokenText: '',
      recordingDurationSeconds: 0,
      soundLevel: 0.0,
      voiceErrorMessage: null,
    );

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(
        recordingDurationSeconds: state.recordingDurationSeconds + 1,
      );
    });

    final success = await _voiceService.startListening(
      onResult: (spokenText, isFinal) {
        state = state.copyWith(currentSpokenText: spokenText);
      },
      onSoundLevelChange: (level) {
        state = state.copyWith(soundLevel: level);
      },
    );

    if (!success) {
      _recordingTimer?.cancel();
      state = state.copyWith(
        isListening: false,
        voiceErrorMessage:
            'Mikrofon belum diizinkan atau fitur suara tidak tersedia di perangkat ini.',
      );
      return false;
    }
    return true;
  }

  Future<void> stopAndSendVoiceRecording() async {
    _recordingTimer?.cancel();
    await _voiceService.stopListening();
    final spoken = state.currentSpokenText.trim();
    state = state.copyWith(
      isListening: false,
      recordingDurationSeconds: 0,
      soundLevel: 0.0,
    );

    if (spoken.isNotEmpty) {
      await sendUserMessage(spoken);
    }
  }

  Future<void> cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _voiceService.cancelListening();
    state = state.copyWith(
      isListening: false,
      currentSpokenText: '',
      recordingDurationSeconds: 0,
      soundLevel: 0.0,
    );
  }

  Future<void> toggleVoiceListening() async {
    if (state.isListening) {
      await stopAndSendVoiceRecording();
    } else {
      await startVoiceRecording();
    }
  }

  // ── Text-To-Speech (TTS) Methods ─────────────────────────────────

  void toggleTts() {
    if (state.isSpeaking) {
      stopSpeaking();
    }
    state = state.copyWith(isTtsEnabled: !state.isTtsEnabled);
  }

  Future<void> speakMessage(String text, [String? id]) async {
    state = state.copyWith(isSpeaking: true, currentlySpeakingMsgId: id);
    await _ttsService.speak(text);
    if (mounted) {
      state = state.copyWith(isSpeaking: false, currentlySpeakingMsgId: null);
    }
  }

  Future<void> stopSpeaking() async {
    await _ttsService.stop();
    if (mounted) {
      state = state.copyWith(isSpeaking: false, currentlySpeakingMsgId: null);
    }
  }

  // ── Send Message ─────────────────────────────────────────────────

  Future<void> sendUserMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || state.isLoading) return;

    if (state.isSpeaking) {
      await stopSpeaking();
    }

    final userMsg = AiMessageModel(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      content: cleanText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    try {
      final bootstrap = _ref.read(homeBootstrapProvider).value;
      final shift = _ref.read(activeShiftProvider).value;
      final shiftTotals = _ref.read(shiftLiveTotalsProvider).value;

      SalesSummary? salesSummary;
      try {
        salesSummary = await _ref.read(salesSummaryProvider.future);
      } catch (_) {
        salesSummary = _ref.read(salesSummaryProvider).value;
      }

      List<MenuItem> menuItems = [];
      try {
        menuItems = await _ref.read(menuItemsProvider.future);
      } catch (_) {
        menuItems = _ref.read(menuItemsProvider).value ?? [];
      }

      final inventoryAsync = _ref.read(inventoryDashboardDataProvider);
      final inventoryData = inventoryAsync.value;

      final currency = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );

      final sales = salesSummary ?? SalesSummary.empty();
      final topItemsStr = sales.topItems
          .take(5)
          .map((e) => '${e.name} (${e.qty} terjual)')
          .join(', ');
      final methodsStr = sales.revenueByMethod.entries
          .map((e) => '${e.key}: ${currency.format(e.value)}')
          .join(', ');

      final salesContext = '''
DATA PENJUALAN DASHBOARD HARI INI (REAL-TIME POS):
- Total Pendapatan / Omzet Hari Ini: ${currency.format(sales.totalRevenue)}
- Total Transaksi / Pesanan: ${sales.totalOrders} transaksi
- Total Produk Terjual: ${sales.totalItems} item
- Laba Kotor (Gross Profit): ${currency.format(sales.grossProfit)}
- Pengeluaran Kas Operasional: ${currency.format(sales.totalExpenses)}
- Laba Bersih Hari Ini (Net Profit): ${currency.format(sales.netProfit)} (Margin: ${sales.profitMargin.toStringAsFixed(1)}%)
- Total Omzet Bulan Ini: ${currency.format(sales.monthlyRevenue)}
- Rata-rata Belanja per Pesanan (AOV): ${currency.format(sales.avgOrderValue)}
- Produk Terlaris Hari Ini: ${topItemsStr.isNotEmpty ? topItemsStr : 'Belum ada produk terjual hari ini'}
- Rincian Metode Bayar: ${methodsStr.isNotEmpty ? methodsStr : '-'}
''';

      final totalProductsCount = menuItems.length;
      final lowStockList = inventoryData?.lowStockItems ?? [];
      final lowStockStr = lowStockList.isNotEmpty
          ? lowStockList
              .take(8)
              .map((e) => '${e.name} (sisa ${e.stockQuantity} unit)')
              .join(', ')
          : 'Semua stok produk dalam kondisi aman.';

      final sampleProducts = menuItems
          .take(25)
          .map((e) => '- ${e.name} (${e.categoryName}): ${currency.format(e.price)}')
          .join('\n');

      final catalogContext = '''
KATALOG PRODUK & STOK TOKO:
- Total Produk Aktif: $totalProductsCount produk
- Peringatan Stok Menipis (<15 unit): $lowStockStr
- Daftar Sebagian Produk Toko:
$sampleProducts
''';

      final shiftContext = shift != null
          ? 'STATUS SHIFT KASIR (LACI FISIK AKTIF):\n'
              '- Kasir/Staf Bertugas: ${shift.cashierName}\n'
              '- Jam Buka Shift: ${DateFormat('dd MMM HH:mm').format(shift.openedAt)}\n'
              '- Modal Kas Awal: ${currency.format(shift.startingCash)}\n'
              '- Penjualan Tunai di Shift: ${currency.format(shiftTotals?['totalSalesCash'] ?? 0)}\n'
              '- Kas Masuk Lain: ${currency.format(shiftTotals?['totalCashIn'] ?? 0)}\n'
              '- Kas Keluar/Biaya di Shift: ${currency.format(shiftTotals?['totalCashOut'] ?? 0)}\n'
              '- Estimasi Kas Fisik Laci Saat Ini: ${currency.format(shiftTotals?['expectedCash'] ?? shift.startingCash)}'
          : 'STATUS SHIFT KASIR: Shift kasir saat ini tidak aktif / belum dibuka (Catatan: Shift kasir bersifat opsional khusus kas laci fisik, transaksi di atas tetap tercatat otomatis di dashboard POS).';

      final systemPrompt = '''
Kamu adalah "Asisten AI Syupeo", asisten bisnis cerdas & konsultan eksekutif untuk pemilik toko & kasir aplikasi Syupeo.
Bisnis: ${state.businessName}
Outlet: ${bootstrap?.currentOutlet?.name ?? 'Outlet Utama'}

$salesContext

$catalogContext

$shiftContext

PANDUAN PERILAKU & ANALISIS BISNIS CERDAS:
1. Jawab secara ramah, profesional, ringkas, dan solutif dalam Bahasa Indonesia.
2. FORMAT RESPON SUARA: Awali jawaban dengan 1-2 kalimat ringkasan inti yang enak didengar ketika dibacakan suara (Text-to-Speech), lalu lengkapi dengan poin-poin penjelasan.
3. PREDIKSI STOK (BURN RATE): Untuk stok yang menipis (<15 unit), berikan estimasi hari kehabisan stok berdasarkan kecepatan penjualan rata-rata dan sarankan kapan harus kulak/belanja.
4. PROMO BUNDLING & MENU ENGINEERING: Jika ditanya cara menaikkan omzet atau ide promo, sarankan bundling antara produk terlaris dengan produk bermargin tinggi agar nilai transaksi (AOV) naik.
5. DATA PENJUALAN REAL-TIME: Untuk pertanyaan omzet, laba, atau transaksi, SELALU gunakan data real-time dashboard di atas. Shift kasir bersifat opsional, jangan menjawab Rp 0 hanya karena shift belum dibuka!
6. PANDUAN APLIKASI: Jika ditanya cara penggunaan Syupeo (buka/tutup shift, cetak struk, diskon), berikan panduan praktis to-the-point.
7. FORMAT TAMPILAN BERSIH & RAPI:
   - JANGAN MENUMPUK SIMBOL MARKDOWN seperti `### **Judul**` atau `* **Poin:**`. Cukup gunakan judul bersih (misal: "### 1. Nama Paket") dan poin rapi (misal: "- Konsep: ..." atau penomoran 1, 2, 3).
   - HINDARI penggunaan garis pemisah `---` berulang-ulang yang mengotori layar.
''';

      final history = state.messages
          .where((m) => !m.isError && m.id != 'welcome-1')
          .take(8)
          .map((m) => {
                'role': m.isUser ? 'user' : 'model',
                'text': m.content,
              })
          .toList();

      final responseText = await _gemini.generateChat(
        systemPrompt: systemPrompt,
        history: history,
        userMessage: cleanText,
      );

      final aiMsg = AiMessageModel(
        id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
        content: responseText,
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );

      // Speak back response via Text-To-Speech if enabled
      if (state.isTtsEnabled) {
        unawaited(speakMessage(responseText, aiMsg.id));
      }
    } catch (e) {
      final errorMsg = AiMessageModel(
        id: 'err-${DateTime.now().millisecondsSinceEpoch}',
        content:
            'Mohon maaf, terjadi kendala saat memproses respon: ${e.toString().replaceAll('Exception: ', '')}. Silakan coba tanyakan kembali.',
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMsg],
        isLoading: false,
      );
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _voiceService.cancelListening();
    _ttsService.dispose();
    super.dispose();
  }

  void clearConversation() {
    _recordingTimer?.cancel();
    _voiceService.cancelListening();
    _ttsService.stop();
    _init();
  }
}
