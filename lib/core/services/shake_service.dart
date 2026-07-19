import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeService {
  static final ShakeService instance = ShakeService._init();
  StreamSubscription? _subscription;
  DateTime? _lastShakeTime;
  bool _isEnabled = true;

  // Constants for shake detection
  static const double shakeThreshold = 13.0; // Acceleration threshold
  static const int shakeIntervalMs = 1000; // Minimum time between shakes in ms

  ShakeService._init();

  void enable(bool value) {
    _isEnabled = value;
    if (!value) {
      stopListening();
    }
  }

  void startListening({required Function() onShake}) {
    if (!_isEnabled) return;
    stopListening();

    _subscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      // Calculate total acceleration magnitude
      final double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      if (acceleration > shakeThreshold) {
        final now = DateTime.now();
        if (_lastShakeTime == null || 
            now.difference(_lastShakeTime!).inMilliseconds > shakeIntervalMs) {
          _lastShakeTime = now;
          onShake();
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
