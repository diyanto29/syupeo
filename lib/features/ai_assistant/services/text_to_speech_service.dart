import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _flutterTts = FlutterTts();

      // Configure Indonesian language
      await _flutterTts?.setLanguage("id-ID");
      await _flutterTts?.setSpeechRate(Platform.isIOS ? 0.5 : 0.85);
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
        debugPrint('[TTS] Error: $msg');
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('[TTS] Init exception: $e');
    }
  }

  /// Clean markdown symbols so TTS reads naturally in Indonesian
  String cleanMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // Bold
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Italic
        .replaceAll(RegExp(r'#{1,6}\s?'), '') // Headings
        .replaceAll(RegExp(r'`{1,3}[^`]*`{1,3}'), '') // Code blocks
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1') // Links
        .replaceAll(RegExp(r'[•\-\*]\s'), ', ') // Bullets to pauses
        .replaceAll(RegExp(r'\n+'), '. ') // Newlines to sentences
        .trim();
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await init();
    }

    final clean = cleanMarkdown(text);
    if (clean.isEmpty) return;

    try {
      await stop();
      _isSpeaking = true;
      await _flutterTts?.speak(clean);
    } catch (e) {
      _isSpeaking = false;
      debugPrint('[TTS] Speak error: $e');
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
