import 'package:flutter/services.dart';

class ShakeDetectionService {
  static const _channel = MethodChannel('com.example.voice_recoginization_app/shake');
  
  static Function? _onShakeDetected;
    static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShakeDetected') {
        _onShakeDetected?.call();
      }
    });
  }
    static void setOnShakeDetectedCallback(Function callback) {
    _onShakeDetected = callback;
  }
  
  static Future<void> startDetection() async {
    try {
      await _channel.invokeMethod('startShakeDetection');
    } catch (e) {
      print('ShakeDetectionService: Failed to start detection: $e');
    }
  }
    static Future<void> stopDetection() async {
    try {
      await _channel.invokeMethod('stopShakeDetection');
    } catch (e) {
      print('ShakeDetectionService: Failed to stop detection: $e');
    }
  }
}
