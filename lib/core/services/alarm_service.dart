import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../database/models.dart';
import '../database/local_repository.dart';

/// Service for managing alarms with both local storage and Android system integration.
/// Supports background execution and real system alarm setting.
class AlarmService {
  static final AlarmService instance = AlarmService._init();
  AlarmService._init();

  static const _alarmChannel = MethodChannel('com.example.voice_recoginization_app/alarm');

  /// Sets an alarm both in the local app and in the Android system Clock app.
  /// 
  /// [hour] and [minute] should be in 24-hour format.
  /// [label] is the alarm label/description.
  /// [repeatDays] is a comma-separated list of days (e.g., "Mon,Tue,Wed").
  /// [repository] is the local repository for storing alarm data.
  /// 
  /// Returns true if both local and system alarms were set successfully.
  Future<bool> setAlarm({
    required int hour,
    required int minute,
    required String label,
    required String repeatDays,
    required LocalRepository repository,
  }) async {
    try {
      debugPrint('AlarmService: Starting alarm set process for $hour:$minute');
      
      // 1. Save to local database
      final hourStr = hour.toString().padLeft(2, '0');
      final minStr = minute.toString().padLeft(2, '0');
      
      final alarm = Alarm(
        id: const Uuid().v4(),
        time: '$hourStr:$minStr',
        label: label,
        isEnabled: true,
        repeatDays: repeatDays,
        createdAt: DateTime.now(),
      );
      
      await repository.insertAlarm(alarm);
      debugPrint('AlarmService: Saved alarm to local database: ${alarm.time} with ID: ${alarm.id}');

      // 2. Set in Android system Clock app
      debugPrint('AlarmService: Attempting to set system alarm');
      final systemSuccess = await _setSystemAlarm(
        hour: hour,
        minute: minute,
        label: label,
      );
      
      if (systemSuccess) {
        debugPrint('AlarmService: System alarm set successfully');
      } else {
        debugPrint('AlarmService: System alarm failed, but local alarm saved');
      }

      debugPrint('AlarmService: Alarm set process completed. System success: $systemSuccess');
      return systemSuccess;
    } catch (e) {
      debugPrint('AlarmService: Error setting alarm: $e');
      debugPrint('AlarmService: Error stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Sets a real alarm in the Android system Clock app.
  /// 
  /// Uses the AlarmClock.ACTION_SET_ALARM intent which every Android Clock
  /// app implements. This ensures the alarm will work even when the app is
  /// in the background or closed.
  Future<bool> _setSystemAlarm({
    required int hour,
    required int minute,
    required String label,
  }) async {
    try {
      debugPrint('AlarmService: Setting system alarm for $hour:$minute with label: $label');
      
      // Request SCHEDULE_EXACT_ALARM permission for Android 12+
      final hasPermission = await _requestExactAlarmPermission();
      debugPrint('AlarmService: Exact alarm permission granted: $hasPermission');
      
      // Try simpler intent approach for better compatibility
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: <String, dynamic>{
          'android.intent.extra.alarm.HOUR': hour,
          'android.intent.extra.alarm.MINUTES': minute,
          'android.intent.extra.alarm.MESSAGE': label,
          // Remove SKIP_UI as it may cause issues on some devices
          // 'android.intent.extra.alarm.SKIP_UI': true,
          // Set vibration
          'android.intent.extra.alarm.VIBRATE': true,
        },
      );
      
      debugPrint('AlarmService: Launching SET_ALARM intent');
      await intent.launch();
      debugPrint('AlarmService: Intent launched successfully');
      return true;
    } catch (e) {
      debugPrint('AlarmService: Failed to set system alarm: $e');
      debugPrint('AlarmService: Error type: ${e.runtimeType}');
      
      // Try alternative approach without extras
      try {
        debugPrint('AlarmService: Trying fallback approach');
        final fallbackIntent = AndroidIntent(
          action: 'android.intent.action.SET_ALARM',
          arguments: <String, dynamic>{
            'hour': hour,
            'minutes': minute,
            'message': label,
          },
        );
        await fallbackIntent.launch();
        debugPrint('AlarmService: Fallback intent launched');
        return true;
      } catch (fallbackError) {
        debugPrint('AlarmService: Fallback also failed: $fallbackError');
        return false;
      }
    }
  }

  /// Requests SCHEDULE_EXACT_ALARM permission for Android 12+ (API 31+)
  Future<bool> _requestExactAlarmPermission() async {
    try {
      // Only needed for Android 12+
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.scheduleExactAlarm.status;
        if (status.isGranted) {
          return true;
        }
        if (status.isPermanentlyDenied) {
          debugPrint('AlarmService: Exact alarm permission permanently denied, user needs to enable in settings');
          return false;
        }
        final result = await Permission.scheduleExactAlarm.request();
        if (result.isPermanentlyDenied) {
          debugPrint('AlarmService: Exact alarm permission permanently denied after request');
          return false;
        }
        return result.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('AlarmService: Error requesting exact alarm permission: $e');
      return false;
    }
  }

  /// Deletes an alarm from both local database and attempts to remove from system.
  /// 
  /// Note: Removing from system Clock app is limited by Android security -
  /// we can only open the alarm editing screen for the user to confirm deletion.
  Future<bool> deleteAlarm({
    required String alarmId,
    required LocalRepository repository,
  }) async {
    try {
      // Delete from local database
      await repository.deleteAlarm(alarmId);
      debugPrint('AlarmService: Deleted alarm from local database: $alarmId');

      // Note: We cannot programmatically delete from system Clock app due to
      // Android security restrictions. The user must delete it manually or
      // we can open the Clock app for them.
      
      return true;
    } catch (e) {
      debugPrint('AlarmService: Error deleting alarm: $e');
      return false;
    }
  }

  /// Toggles an alarm's enabled state in local database.
  /// 
  /// System alarm sync is limited - we can only set new alarms, not modify
  // existing ones programmatically.
  Future<bool> toggleAlarm({
    required Alarm alarm,
    required LocalRepository repository,
  }) async {
    try {
      final updated = Alarm(
        id: alarm.id,
        time: alarm.time,
        label: alarm.label,
        isEnabled: !alarm.isEnabled,
        repeatDays: alarm.repeatDays,
        createdAt: alarm.createdAt,
      );
      
      await repository.updateAlarm(updated);
      debugPrint('AlarmService: Toggled alarm ${alarm.id} to ${updated.isEnabled}');
      
      // If enabling, set a new system alarm
      if (updated.isEnabled) {
        final hm = _parseTimeToHourMinute(alarm.time);
        if (hm != null) {
          await _setSystemAlarm(
            hour: hm[0],
            minute: hm[1],
            label: alarm.label,
          );
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('AlarmService: Error toggling alarm: $e');
      return false;
    }
  }

  /// Opens the Android Clock app at the alarm screen.
  /// Useful when users need to manage system alarms manually.
  Future<bool> openSystemAlarmApp() async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: 'com.android.deskclock', // Default Android Clock app
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('AlarmService: Failed to open Clock app: $e');
      return false;
    }
  }

  /// Parses a time string like "7 PM", "07:30 AM", "9:00 PM" into [hour, minute]
  /// in 24-hour format. Returns null if it can't be parsed.
  List<int>? _parseTimeToHourMinute(String time) {
    if (time.isEmpty) return null;
    final t = time.toUpperCase().trim();
    final match = RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)?').firstMatch(t);
    if (match == null) return null;

    int hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final period = match.group(3);

    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    if (hour > 23) hour = 23;
    if (minute > 59) return [hour, 0];
    return [hour, minute];
  }

  /// Initializes the alarm service for background operation.
  /// Call this from main.dart or when the app starts.
  static Future<void> initialize() async {
    try {
      // Request necessary permissions
      await instance._requestExactAlarmPermission();
      
      // Set up method channel handler for background alarm callbacks
      _alarmChannel.setMethodCallHandler((call) async {
        debugPrint('AlarmService: Received method call: ${call.method}');
        switch (call.method) {
          case 'onAlarmTriggered':
            // Handle alarm triggered from system
            final alarmId = call.arguments as String?;
            debugPrint('AlarmService: Alarm triggered: $alarmId');
            // You can trigger local notification here
            break;
          default:
            debugPrint('AlarmService: Unknown method: ${call.method}');
        }
      });
      
      debugPrint('AlarmService: Initialized successfully');
    } catch (e) {
      debugPrint('AlarmService: Initialization error: $e');
    }
  }
}
