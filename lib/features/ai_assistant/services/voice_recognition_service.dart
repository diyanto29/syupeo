import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  String? _resolvedLocale;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (val) => debugPrint('STT Error: ${val.errorMsg} (${val.permanent})'),
        onStatus: (val) => debugPrint('STT Status: $val'),
        debugLogging: kDebugMode,
      );

      if (_isInitialized) {
        try {
          final locales = await _speech.locales();
          for (final l in locales) {
            final id = l.localeId.toLowerCase();
            if (id.startsWith('id') || id.startsWith('in')) {
              _resolvedLocale = l.localeId;
              break;
            }
          }
        } catch (_) {
          _resolvedLocale = 'id_ID';
        }
      }
      return _isInitialized;
    } catch (e) {
      debugPrint('STT Initialize exception: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<bool> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(double level)? onSoundLevelChange,
  }) async {
    final available = await initialize();
    if (!available) {
      onResult('', true);
      return false;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: onSoundLevelChange,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 5),
        localeId: _resolvedLocale ?? 'id_ID',
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('STT Listen exception: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
