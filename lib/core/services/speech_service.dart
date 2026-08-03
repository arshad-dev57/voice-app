import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// Service that manages speech recognition for the voice assistant.
///
/// Key design decisions:
///
/// 1. **Always use en-US locale for STT**.
///    Google's en-US model handles code-switching very well — it can recognise
///    Roman-Urdu words like "karo", "ko", "lagao" alongside English.
///
/// 2. **Guaranteed Completion & Timeout Recovery**.
///    STT timeouts (e.g. error_speech_timeout) or status transitions (notListening/done)
///    are forwarded to the session callbacks. The state never gets frozen in
///    `OrbState.listening`.
class SpeechService {
  static final SpeechService instance = SpeechService._init();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _hasCompleted = false;
  String _lastRecognizedText = '';

  // Active session callbacks
  Function(String finalText)? _activeOnDone;
  VoidCallback? _activeOnError;
  VoidCallback? _activeOnComplete;

  SpeechService._init();

  void setLanguageCode(String languageCode) {
    debugPrint('SpeechService: setLanguageCode called with $languageCode (en-US is enforced for STT)');
  }

  static const String _sttLocale = 'en-US';

  // ---------------------------------------------------------------------- //
  //  Initialization                                                          //
  // ---------------------------------------------------------------------- //

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (val) {
          debugPrint('SpeechService Error: ${val.errorMsg}');
          if (!_hasCompleted) {
            _hasCompleted = true;
            if (_lastRecognizedText.trim().isNotEmpty && _activeOnDone != null) {
              _activeOnDone?.call(_lastRecognizedText);
            } else if (_activeOnError != null) {
              _activeOnError?.call();
            } else if (_activeOnDone != null) {
              _activeOnDone?.call('');
            }
          }
        },
        onStatus: (status) {
          debugPrint('SpeechService Status: $status');
          if ((status == 'notListening' || status == 'done') && !_hasCompleted) {
            _hasCompleted = true;
            debugPrint('SpeechService: status transition $status -> firing completion with "$_lastRecognizedText"');
            if (_activeOnDone != null) {
              _activeOnDone?.call(_lastRecognizedText);
            } else if (_activeOnComplete != null) {
              _activeOnComplete?.call();
            }
          }
        },
      );
      debugPrint('SpeechService initialized: $_isInitialized (locale: $_sttLocale)');
    } catch (e) {
      debugPrint('SpeechService init exception: $e');
      _isInitialized = false;
    }
    return _isInitialized;
  }

  // ---------------------------------------------------------------------- //
  //  Permission                                                              //
  // ---------------------------------------------------------------------- //

  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      debugPrint('SpeechService: Microphone permission permanently denied');
      return false;
    }
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  // ---------------------------------------------------------------------- //
  //  Listening                                                               //
  // ---------------------------------------------------------------------- //

  Future<void> startListening({
    required Function(String text) onResult,
    required VoidCallback onError,
    Function(String finalText)? onDone,
    VoidCallback? onComplete,
    VoidCallback? onSoundLevelChanged,
  }) async {
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      debugPrint('SpeechService: microphone permission denied');
      onError();
      return;
    }

    final isReady = await initialize();
    if (!isReady) {
      debugPrint('SpeechService: not initialized');
      onError();
      return;
    }

    _hasCompleted = false;
    _lastRecognizedText = '';
    _activeOnDone = onDone;
    _activeOnError = onError;
    _activeOnComplete = onComplete;

    try {
      await _speech.listen(
        localeId: _sttLocale,
        onResult: (result) {
          _lastRecognizedText = result.recognizedWords;
          onResult(result.recognizedWords);

          if (result.finalResult && !_hasCompleted) {
            _hasCompleted = true;
            debugPrint('SpeechService: final result = "$_lastRecognizedText"');
            if (onDone != null) {
              onDone(_lastRecognizedText);
            } else if (onComplete != null) {
              onComplete();
            }
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    } catch (e) {
      debugPrint('SpeechService: listen error: $e');
      if (!_hasCompleted) {
        _hasCompleted = true;
        onError();
      }
    }
  }

  Future<void> stopListening() async {
    if (_isInitialized && _speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancelListening() async {
    if (_isInitialized) {
      await _speech.cancel();
    }
    _hasCompleted = true;
  }

  bool get isListening => _speech.isListening;
}
