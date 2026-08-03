import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flutter-side bridge to the native ShakeDetectionService foreground service.
///
/// Fixes applied:
///  - [initialize] now calls [startDetection] automatically so the Android
///    foreground service actually starts (previously it was never started).
///  - Duplicate ShakeService (sensors_plus) has been removed — this single
///    class is the canonical shake implementation backed by the native service.
class ShakeDetectionService {
  static const _channel =
      MethodChannel('com.example.voice_recoginization_app/shake');

  static Function? _onShakeDetectedCallback;
  static bool _isInitialized = false;

  /// Initializes the method channel handler AND starts the native foreground
  /// service. Must be called once at app startup.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Register the handler that receives 'onShakeDetected' from native side
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShakeDetected') {
        debugPrint('ShakeDetectionService: shake detected from native service');
        _onShakeDetectedCallback?.call();
      }
    });

    // Start the native Android foreground service
    // This was the missing call — without this, the service never ran
    await startDetection();

    _isInitialized = true;
    debugPrint('ShakeDetectionService: initialized and native service started');
  }

  /// Sets the callback that fires when a shake is detected.
  static void setOnShakeDetectedCallback(Function callback) {
    _onShakeDetectedCallback = callback;
  }

  /// Starts the Android foreground service (ShakeDetectionService.kt).
  static Future<void> startDetection() async {
    try {
      await _channel.invokeMethod('startShakeDetection');
      debugPrint('ShakeDetectionService: native service start requested');
    } catch (e) {
      debugPrint('ShakeDetectionService: failed to start detection: $e');
    }
  }

  /// Stops the Android foreground service.
  static Future<void> stopDetection() async {
    try {
      await _channel.invokeMethod('stopShakeDetection');
      _isInitialized = false;
      debugPrint('ShakeDetectionService: native service stopped');
    } catch (e) {
      debugPrint('ShakeDetectionService: failed to stop detection: $e');
    }
  }
}
