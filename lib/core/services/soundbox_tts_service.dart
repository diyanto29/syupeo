import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Helper untuk mengonversi angka nominal uang Rupiah ke teks terbilang bahasa Indonesia.
/// Contoh: 25000 -> "dua puluh lima ribu"
class TerbilangRupiah {
  TerbilangRupiah._();

  static String convert(int number) {
    if (number == 0) return 'nol';
    if (number < 0) return 'minus ${convert(-number)}';

    const satuan = [
      '',
      'satu',
      'dua',
      'tiga',
      'empat',
      'lima',
      'enam',
      'tujuh',
      'delapan',
      'sembilan',
      'sepuluh',
      'sebelas',
    ];

    if (number < 12) {
      return satuan[number];
    } else if (number < 20) {
      return '${convert(number - 10)} belas';
    } else if (number < 100) {
      final sisa = number % 10;
      return '${convert(number ~/ 10)} puluh${sisa > 0 ? " ${convert(sisa)}" : ""}';
    } else if (number < 200) {
      final sisa = number - 100;
      return 'seratus${sisa > 0 ? " ${convert(sisa)}" : ""}';
    } else if (number < 1000) {
      final sisa = number % 100;
      return '${convert(number ~/ 100)} ratus${sisa > 0 ? " ${convert(sisa)}" : ""}';
    } else if (number < 2000) {
      final sisa = number - 1000;
      return 'seribu${sisa > 0 ? " ${convert(sisa)}" : ""}';
    } else if (number < 1000000) {
      final sisa = number % 1000;
      return '${convert(number ~/ 1000)} ribu${sisa > 0 ? " ${convert(sisa)}" : ""}';
    } else if (number < 1000000000) {
      final sisa = number % 1000000;
      return '${convert(number ~/ 1000000)} juta${sisa > 0 ? " ${convert(sisa)}" : ""}';
    } else {
      final sisa = number % 1000000000;
      return '${convert(number ~/ 1000000000)} miliar${sisa > 0 ? " ${convert(sisa)}" : ""}';
    }
  }
}

/// Service Text-to-Speech khusus Virtual Soundbox Syupeo
class SoundboxTtsService {
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();

      // Konfigurasi suara Bahasa Indonesia tenang & jelas seperti soundbox fisik
      await _flutterTts?.setLanguage("id-ID");
      await _flutterTts?.setSpeechRate(0.48);
      await _flutterTts?.setVolume(1.0);
      await _flutterTts?.setPitch(1.0);

      _flutterTts?.setStartHandler(() {
        _isSpeaking = true;
      });

      _flutterTts?.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _flutterTts?.setCancelHandler(() {
        _isSpeaking = false;
      });

      _flutterTts?.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('[SoundboxTTS] Error: $msg');
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('[SoundboxTTS] Init exception: $e');
    }
  }

  /// Ubah kecepatan bicara secara dinamis (0.35 - 0.70)
  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) await init();
    await _flutterTts?.setSpeechRate(rate);
  }

  /// Bicara format pengumuman Soundbox resmi
  /// Contoh: "Pembayaran QRIS GoPay sebesar dua puluh lima ribu rupiah telah diterima."
  Future<void> speakPayment({
    required String appName,
    required int amount,
    String? sender,
    double? speechRate,
  }) async {
    final terbilang = TerbilangRupiah.convert(amount);
    final cleanAppName = appName.trim().isEmpty ? 'QRIS' : appName.trim();

    final sentence =
        'Pembayaran $cleanAppName sebesar $terbilang rupiah telah diterima.';

    await speak(sentence, rate: speechRate);
  }

  Future<void> speak(String text, {double? rate}) async {
    if (!_isInitialized) {
      await init();
    }

    if (text.trim().isEmpty) return;

    try {
      await stop();
      if (rate != null) {
        await _flutterTts?.setSpeechRate(rate);
      }
      _isSpeaking = true;
      await _flutterTts?.speak(text.trim());
    } catch (e) {
      _isSpeaking = false;
      debugPrint('[SoundboxTTS] Speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      _isSpeaking = false;
      await _flutterTts?.stop();
    } catch (_) {}
  }

  void dispose() {
    stop();
  }
}

/// Provider singleton SoundboxTtsService
final soundboxTtsServiceProvider = Provider<SoundboxTtsService>((ref) {
  final service = SoundboxTtsService();
  ref.onDispose(() => service.dispose());
  return service;
});
