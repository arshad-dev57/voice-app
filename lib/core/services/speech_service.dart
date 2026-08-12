import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'language_detector.dart';

/// Speech recognition for English, Urdu, and Roman Urdu.
///
/// Roman Urdu is recognised by the English (en-US) model. Native Urdu uses
/// ur-PK when the device has that locale installed. Locale can switch mid
/// session when [setLanguageCode] is called after language detection.
class SpeechService {
  static final SpeechService instance = SpeechService._init();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _hasCompleted = false;
  String _lastRecognizedText = '';
  String _localeId = 'en-US';
  List<stt.LocaleName> _locales = const [];

  Function(String finalText)? _activeOnDone;
  VoidCallback? _activeOnError;
  VoidCallback? _activeOnComplete;

  SpeechService._init();

  void setLanguageCode(String languageCode) {
    _localeId = _resolveLocale(LanguageDetector.sttLocale(languageCode));
    debugPrint('SpeechService: STT locale set to $_localeId');
  }

  String _resolveLocale(String preferred) {
    if (_locales.isEmpty) return preferred;
    final exact = _locales.where((l) => l.localeId == preferred);
    if (exact.isNotEmpty) return preferred;

    if (preferred.startsWith('ur')) {
      final urdu = _locales.where(
        (l) => l.localeId.toLowerCase().startsWith('ur'),
      );
      if (urdu.isNotEmpty) return urdu.first.localeId;
    }
    final en = _locales.where(
      (l) => l.localeId == 'en-US' || l.localeId == 'en_US',
    );
    if (en.isNotEmpty) return en.first.localeId;
    return preferred;
  }

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
            if (_activeOnDone != null) {
              _activeOnDone?.call(_lastRecognizedText);
            } else if (_activeOnComplete != null) {
              _activeOnComplete?.call();
            }
          }
        },
      );
      if (_isInitialized) {
        try {
          _locales = await _speech.locales();
        } catch (_) {}
        _localeId = _resolveLocale(_localeId);
      }
      debugPrint('SpeechService initialized: $_isInitialized (locale: $_localeId)');
    } catch (e) {
      debugPrint('SpeechService init exception: $e');
      _isInitialized = false;
    }
    return _isInitialized;
  }

  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required VoidCallback onError,
    Function(String finalText)? onDone,
    VoidCallback? onComplete,
    VoidCallback? onSoundLevelChanged,
  }) async {
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      onError();
      return;
    }

    final isReady = await initialize();
    if (!isReady) {
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
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
          localeId: _localeId,
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
