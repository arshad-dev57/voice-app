import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService instance = TtsService._init();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  // Current TTS locale. Switched based on the user's selected language.
  // 'en' / 'roman_ur' -> en-US, 'ur' -> ur-PK.
  String _locale = 'en-US';

  TtsService._init() {
    _initTts();
  }

  /// Maps the app language code to a device TTS locale and stores it so
  /// every subsequent [speak] call uses the correct voice.
  void setLanguageCode(String languageCode) {
    switch (languageCode) {
      case 'ur':
        _locale = 'ur-PK';
        break;
      case 'roman_ur':
      case 'en':
      default:
        _locale = 'en-US';
    }
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      print("TTS Error: $msg");
    });
  }

  /// Speaks [text]. If [locale] is not provided it falls back to the
  /// locale set via [setLanguageCode] (driven by the user's language setting).
  Future<void> speak(String text, {String? locale}) async {
    try {
      await _flutterTts.setLanguage(locale ?? _locale);
      await _flutterTts.speak(text);
    } catch (e) {
      print('TTS Speak Exception: $e');
    }
  }

  Future<void> setRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  bool get isSpeaking => _isSpeaking;
}
