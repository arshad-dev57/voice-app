import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class SpeechService {
  static final SpeechService instance = SpeechService._init();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  SpeechService._init();

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (val) => debugPrint('SpeechService Error: $val'),
        onStatus: (val) => debugPrint('SpeechService Status: $val'),
      );
      debugPrint('SpeechService initialized: $_isInitialized');
    } catch (e) {
      debugPrint('SpeechService Initialization Exception: $e');
      _isInitialized = false;
    }
    return _isInitialized;
  }

  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final request = await Permission.microphone.request();
    return request.isGranted;
  }

  Future<void> startListening({
    required Function(String text) onResult,
    required VoidCallback onSoundLevelChanged,
    required VoidCallback onError,
    required VoidCallback onComplete,
  }) async {
    bool hasPermission = await checkPermission();
    if (!hasPermission) {
      onError();
      return;
    }

    bool isReady = await initialize();
    if (!isReady) {
      onError();
      return;
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onResult(result.recognizedWords);
            onComplete();
          } else {
            onResult(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 15),
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('Speech listen error: $e');
      onError();
    }
  }

  Future<void> stopListening() async {
    if (_isInitialized) {
      await _speech.stop();
    }
  }

  Future<void> cancelListening() async {
    if (_isInitialized) {
      await _speech.cancel();
    }
  }

  bool get isListening => _speech.isListening;
}
