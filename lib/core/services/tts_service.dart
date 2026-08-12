import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'language_detector.dart';

/// Text-to-speech. Replies in English, Urdu, or Roman Urdu.
///
/// Roman Urdu is spoken with the English voice (Latin script). Urdu script
/// uses ur-PK when the voice pack is installed, otherwise falls back to en-US.
class TtsService {
  static final TtsService instance = TtsService._init();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  String _locale = 'en-US';

  TtsService._init() {
    _initTts();
  }

  void setLanguageCode(String languageCode) {
    _locale = LanguageDetector.ttsLocale(languageCode);
    debugPrint('TtsService: language set to $_locale');
  }

  void _initTts() {
    _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      debugPrint('TTS Error: $msg');
    });
  }

  Future<void> speak(String text, {String? locale}) async {
    if (text.trim().isEmpty) return;
    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
      }

      final targetLocale = locale ?? _locale;
      final langResult = await _flutterTts.setLanguage(targetLocale);
      if (langResult != 1 && targetLocale != 'en-US') {
        debugPrint('TtsService: $targetLocale not available, falling back to en-US');
        await _flutterTts.setLanguage('en-US');
      }

      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TtsService: speak error: $e');
      _isSpeaking = false;
    }
  }

  Future<void> setRate(double rate) async {
    await _flutterTts.setSpeechRate(rate.clamp(0.1, 2.0));
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _isSpeaking = false;
  }

  bool get isSpeaking => _isSpeaking;
}
