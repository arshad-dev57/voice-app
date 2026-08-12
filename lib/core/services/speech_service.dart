import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'language_detector.dart';
import 'nlp_engine.dart';
import 'speech_corrector.dart';

/// High-accuracy speech recognition for English, Urdu, and Roman Urdu.
///
/// Accuracy strategy:
///  - Lock to en-IN for English/Roman Urdu (South Asian accent model)
///  - Never flip locale mid-session from auto-detect (that causes garbage)
///  - Wait for a real final result instead of a truncated partial
///  - Score STT alternates against known commands
///  - Phonetic-correct common mishearings before handing text to NLP
class SpeechService {
  static final SpeechService instance = SpeechService._init();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _hasCompleted = false;
  bool _commandMode = true;
  String _lastRecognizedText = '';
  double _lastConfidence = 0;
  String _localeId = 'en-IN';
  List<stt.LocaleName> _locales = const [];
  Timer? _finalizeTimer;

  Function(String finalText)? _activeOnDone;
  VoidCallback? _activeOnError;
  VoidCallback? _activeOnComplete;

  SpeechService._init();

  double get lastConfidence => _lastConfidence;

  /// Settings language only. Do not call this from auto-detect.
  void setLanguageCode(String languageCode) {
    final preferred = LanguageDetector.sttLocale(languageCode);
    _localeId = _resolveLocale(preferred);
    debugPrint('SpeechService: STT locale set to $_localeId');
  }

  String _resolveLocale(String preferred) {
    if (_locales.isEmpty) return preferred;

    String? findPrefix(String prefix) {
      final matches = _locales.where(
        (l) => l.localeId.toLowerCase().replaceAll('_', '-').startsWith(prefix),
      );
      return matches.isEmpty ? null : matches.first.localeId;
    }

    if (preferred.toLowerCase().startsWith('ur')) {
      return findPrefix('ur-pk') ??
          findPrefix('ur') ??
          findPrefix('en-in') ??
          preferred;
    }

    // South Asian English first — much better for Pakistani accents
    // and Roman Urdu than en-US.
    return findPrefix('en-in') ??
        findPrefix('en-gb') ??
        findPrefix('en-us') ??
        findPrefix('en') ??
        preferred;
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (val) {
          debugPrint('SpeechService Error: ${val.errorMsg}');
          final msg = val.errorMsg.toLowerCase();
          final hasText = _lastRecognizedText.trim().isNotEmpty;
          // Timeouts still often have usable words — keep them.
          if (hasText &&
              (msg.contains('timeout') ||
                  msg.contains('speech_timeout') ||
                  msg.contains('no_match'))) {
            _commit(_lastRecognizedText);
            return;
          }
          if (!_hasCompleted) {
            _hasCompleted = true;
            _finalizeTimer?.cancel();
            if (hasText && _activeOnDone != null) {
              _activeOnDone?.call(_lastRecognizedText);
            } else {
              _activeOnError?.call();
            }
          }
        },
        onStatus: (status) {
          debugPrint('SpeechService Status: $status');
          // Do NOT commit on notListening immediately — Android often fires
          // this with a truncated partial. Wait briefly for the final result.
          if ((status == 'notListening' || status == 'done') &&
              !_hasCompleted) {
            _finalizeTimer?.cancel();
            _finalizeTimer = Timer(const Duration(milliseconds: 500), () {
              if (!_hasCompleted) {
                _commit(_lastRecognizedText);
              }
            });
          }
        },
      );
      if (_isInitialized) {
        try {
          _locales = await _speech.locales();
          debugPrint(
            'SpeechService: available locales: ${_locales.map((l) => l.localeId).join(', ')}',
          );
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
    bool commandMode = true,
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

    if (_speech.isListening) {
      await _speech.cancel();
    }

    _hasCompleted = false;
    _commandMode = commandMode;
    _lastRecognizedText = '';
    _lastConfidence = 0;
    _activeOnDone = onDone;
    _activeOnError = onError;
    _activeOnComplete = onComplete;
    _finalizeTimer?.cancel();

    try {
      await _speech.listen(
        onResult: (result) {
          final picked = _pickBestTranscript(result);
          _lastRecognizedText = picked;
          _lastConfidence = result.confidence;
          onResult(picked);

          if (result.finalResult && !_hasCompleted) {
            _finalizeTimer?.cancel();
            _commit(picked);
          }
        },
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: false,
          partialResults: true,
          onDevice: false,
          listenMode: commandMode
              ? stt.ListenMode.search
              : stt.ListenMode.dictation,
          listenFor: Duration(seconds: commandMode ? 18 : 30),
          pauseFor: Duration(seconds: commandMode ? 3 : 5),
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

  void _commit(String raw) {
    if (_hasCompleted) return;
    _hasCompleted = true;
    _finalizeTimer?.cancel();
    final cleaned = SpeechCorrector.correct(raw, aggressive: _commandMode);
    debugPrint(
      'SpeechService: commit raw="$raw" cleaned="$cleaned" '
      'confidence=$_lastConfidence locale=$_localeId',
    );
    if (_activeOnDone != null) {
      _activeOnDone!(cleaned);
    } else if (_activeOnComplete != null) {
      _activeOnComplete!();
    }
  }

  /// Prefer an alternate that actually looks like a command.
  String _pickBestTranscript(SpeechRecognitionResult result) {
    if (result.alternates.isEmpty) {
      return SpeechCorrector.correct(
        result.recognizedWords,
        aggressive: _commandMode,
      );
    }

    var bestText = result.recognizedWords;
    var bestScore = -1.0;

    for (final alt in result.alternates) {
      final raw = alt.recognizedWords.trim();
      if (raw.isEmpty) continue;
      final corrected = SpeechCorrector.correct(raw, aggressive: _commandMode);
      final parsed = NlpEngine.parse(corrected);

      var score = alt.confidence > 0 ? alt.confidence : 0.45;
      if (parsed.intent != AssistantIntent.unknown) score += 0.35;
      if (parsed.intent == AssistantIntent.call ||
          parsed.intent == AssistantIntent.message ||
          parsed.intent == AssistantIntent.alarm) {
        score += 0.2;
      }
      if (parsed.contactName != null && parsed.contactName!.trim().isNotEmpty) {
        score += 0.15;
      }
      if (corrected.split(' ').length >= 2) score += 0.05;

      if (score > bestScore) {
        bestScore = score;
        bestText = corrected;
      }
    }

    return bestText;
  }

  Future<void> stopListening() async {
    _finalizeTimer?.cancel();
    if (_isInitialized && _speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> cancelListening() async {
    _finalizeTimer?.cancel();
    _hasCompleted = true;
    if (_isInitialized) {
      await _speech.cancel();
    }
  }

  bool get isListening => _speech.isListening;
}
