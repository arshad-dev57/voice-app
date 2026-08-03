import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// Text-to-speech service for the voice assistant.
///
/// Key design decisions:
///
/// 1. **awaitSpeakCompletion(true)**
///    [speak] now awaits until TTS has fully finished before returning.
///    This prevents the microphone from starting while the speaker is
///    still producing TTS output (which would be picked up as speech input).
///
/// 2. **Stop before speaking**
///    Any ongoing TTS is stopped before starting a new utterance.
///    This prevents overlapping speech when the user interrupts.
///
/// 3. **Language fallback**
///    If the device does not have ur-PK TTS installed, falls back to en-US.
///    This ensures blind users always receive spoken feedback.
class TtsService {
  static final TtsService instance = TtsService._init();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  // The locale used for TTS output. Controlled by user language settings.
  // Defaults to en-US which is universally available on Android.
  String _locale = 'en-US';

  TtsService._init() {
    _initTts();
  }

  // ---------------------------------------------------------------------- //
  //  Configuration                                                           //
  // ---------------------------------------------------------------------- //

  /// Maps app language code to TTS locale.
  ///
  /// Note: This ONLY affects TTS (what the assistant says back to the user).
  /// STT (what the user speaks) always uses en-US — see [SpeechService].
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
    debugPrint('TtsService: language set to $_locale');
  }

  void _initTts() {
    // awaitSpeakCompletion ensures speak() only returns after TTS finishes.
    // This is the key fix that prevents the microphone from picking up TTS.
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

  // ---------------------------------------------------------------------- //
  //  Speech                                                                  //
  // ---------------------------------------------------------------------- //

  /// Speaks [text] and awaits completion before returning.
  ///
  /// If [locale] is provided it overrides the stored locale for this call only.
  /// Stops any ongoing speech before starting the new utterance.
  Future<void> speak(String text, {String? locale}) async {
    if (text.trim().isEmpty) return;
    try {
      // Stop any ongoing speech first
      if (_isSpeaking) {
        await _flutterTts.stop();
      }

      final targetLocale = locale ?? _locale;

      // Try to set the requested language; fall back to en-US if unavailable
      final langResult = await _flutterTts.setLanguage(targetLocale);
      if (langResult != 1 && targetLocale != 'en-US') {
        debugPrint('TtsService: $targetLocale not available, falling back to en-US');
        await _flutterTts.setLanguage('en-US');
      }

      await _flutterTts.speak(text);
      // speak() only returns after completion because awaitSpeakCompletion(true)
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
