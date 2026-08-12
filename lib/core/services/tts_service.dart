import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'language_detector.dart';

/// Clear, slow TTS for blind users. Prefers Google TTS + South Asian voices.
class TtsService {
  static final TtsService instance = TtsService._init();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _engineReady = false;
  String _locale = 'en-IN';
  double _rate = 0.4;
  double _pitch = 1.0;
  List<Map<String, String>> _voices = const [];

  TtsService._init() {
    _initTts();
  }

  void setLanguageCode(String languageCode) {
    _locale = LanguageDetector.ttsLocale(languageCode);
    debugPrint('TtsService: language set to $_locale');
  }

  Future<void> _initTts() async {
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

  Future<void> _ensureEngine() async {
    if (_engineReady) return;
    try {
      await _flutterTts.setEngine('com.google.android.tts');
    } catch (e) {
      debugPrint('TtsService: Google engine not set: $e');
    }
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_rate);
      await _flutterTts.setSilence(250);
    } catch (_) {}
    try {
      final raw = await _flutterTts.getVoices;
      if (raw is List) {
        _voices = raw
            .whereType<Map>()
            .map((v) => {
                  'name': '${v['name'] ?? ''}',
                  'locale': '${v['locale'] ?? ''}',
                })
            .where((v) => v['name']!.isNotEmpty && v['locale']!.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('TtsService: getVoices failed: $e');
    }
    _engineReady = true;
  }

  Future<void> _applyVoice(String locale) async {
    await _ensureEngine();
    final want = locale.toLowerCase().replaceAll('_', '-');

    Map<String, String>? matchPrefix(String prefix) {
      for (final v in _voices) {
        final loc = v['locale']!.toLowerCase().replaceAll('_', '-');
        if (loc.startsWith(prefix)) return v;
      }
      return null;
    }

    Map<String, String>? pick;
    pick = matchPrefix(want);
    if (want.startsWith('en')) {
      pick ??= matchPrefix('en-in');
      pick ??= matchPrefix('en-gb');
      pick ??= matchPrefix('en-us');
      pick ??= matchPrefix('en');
    } else if (want.startsWith('ur')) {
      pick ??= matchPrefix('ur-pk');
      pick ??= matchPrefix('ur-in');
      pick ??= matchPrefix('ur');
    }

    if (pick != null) {
      try {
        await _flutterTts.setVoice({
          'name': pick['name']!,
          'locale': pick['locale']!,
        });
        debugPrint('TtsService: voice ${pick['name']} (${pick['locale']})');
      } catch (e) {
        debugPrint('TtsService: setVoice failed: $e');
        await _flutterTts.setLanguage(locale);
      }
    } else {
      final langResult = await _flutterTts.setLanguage(locale);
      if (langResult != 1 && locale != 'en-IN') {
        await _flutterTts.setLanguage('en-IN');
      }
    }

    await _flutterTts.setSpeechRate(_rate);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setVolume(1.0);
  }

  Future<void> speak(String text, {String? locale}) async {
    if (text.trim().isEmpty) return;
    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
      }
      final targetLocale = locale ?? _locale;
      await _applyVoice(targetLocale);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TtsService: speak error: $e');
      _isSpeaking = false;
    }
  }

  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.2, 0.7);
    await _flutterTts.setSpeechRate(_rate);
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.8, 1.2);
    await _flutterTts.setPitch(_pitch);
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _isSpeaking = false;
  }

  bool get isSpeaking => _isSpeaking;
}
