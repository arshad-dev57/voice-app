import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bridges the assistant to Android's real phone, SMS, and Clock apps.
///
/// Call and SMS go through the native Kotlin layer first (TelecomManager /
/// SmsManager) so they actually dial and send without extra taps.
class PhoneService {
  static final PhoneService instance = PhoneService._init();
  PhoneService._init();

  final Telephony _telephony = Telephony.instance;
  static const _accessibilityChannel =
      MethodChannel('com.example.voice_recoginization_app/accessibility');
  static const _phoneChannel =
      MethodChannel('com.example.voice_recoginization_app/phone');
  static const _alarmChannel =
      MethodChannel('com.example.voice_recoginization_app/alarm');

  int? getSimSlotFromName(String simName) {
    final lowerName = simName.toLowerCase().trim();

    if (lowerName.contains('zong') ||
        lowerName.contains('sim 1') ||
        lowerName.contains('first') ||
        lowerName.contains('one')) {
      return 0;
    } else if (lowerName.contains('jazz') ||
        lowerName.contains('telenor') ||
        lowerName.contains('ufone') ||
        lowerName.contains('sim 2') ||
        lowerName.contains('second') ||
        lowerName.contains('two')) {
      return 1;
    }

    if (lowerName.contains('1')) return 0;
    if (lowerName.contains('2')) return 1;

    debugPrint('PhoneService: Could not determine SIM slot for "$simName"');
    return null;
  }

  Future<void> setTargetSim(String simName) async {
    try {
      await _accessibilityChannel.invokeMethod('setTargetSim', {'simName': simName});
    } catch (e) {
      debugPrint('PhoneService: Failed to set target SIM: $e');
    }
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result =
          await _accessibilityChannel.invokeMethod('isAccessibilityServiceEnabled');
      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> makePhoneCall({
    required String phoneNumber,
    int? simSlot,
  }) async {
    final sanitizedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitizedNumber.isEmpty) {
      debugPrint('PhoneService: Phone number is empty after sanitization');
      return false;
    }

    final granted = await _requestCallPermission();
    if (!granted) {
      debugPrint('PhoneService: CALL_PHONE denied — opening dialer');
      return _launchDialerIntent(sanitizedNumber);
    }

    try {
      final native = await _phoneChannel.invokeMethod<bool>('makeCall', {
        'number': sanitizedNumber,
        'simSlot': simSlot,
      });
      if (native == true) {
        debugPrint('PhoneService: native makeCall succeeded');
        return true;
      }
    } catch (e) {
      debugPrint('PhoneService: native makeCall failed: $e');
    }

    return _launchCallIntent(sanitizedNumber, simSlot) ;
  }

  Future<bool> _requestCallPermission() async {
    try {
      final status = await Permission.phone.status;
      if (status.isGranted) return true;
      final result = await Permission.phone.request();
      return result.isGranted;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _launchCallIntent(String phoneNumber, int? simSlot) async {
    try {
      final targetSlot = simSlot ?? 0;
      final intent = AndroidIntent(
        action: 'android.intent.action.CALL',
        data: 'tel:$phoneNumber',
        arguments: <String, dynamic>{
          'com.android.phone.extra.slot': targetSlot,
          'slot': targetSlot,
          'simId': targetSlot,
          'android.telecom.extra.START_CALL_WITH_SPEAKERPHONE': true,
        },
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('PhoneService: CALL intent failed: $e');
      return _launchDialerIntent(phoneNumber);
    }
  }

  Future<bool> _launchDialerIntent(String phoneNumber) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.DIAL',
        data: 'tel:$phoneNumber',
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('PhoneService: DIAL intent failed: $e');
      return false;
    }
  }

  /// Sends a real SMS through Android's system Messages app (SmsManager),
  /// not the in-app chat. Same idea as [makePhoneCall] using the Phone app.
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    final sanitized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitized.isEmpty || message.trim().isEmpty) return false;

    final granted = await requestSmsPermission();
    if (!granted) {
      debugPrint('PhoneService: SMS permission denied.');
      return openSystemMessages(phoneNumber: sanitized);
    }

    try {
      final native = await _phoneChannel.invokeMethod<bool>('sendSms', {
        'number': sanitized,
        'message': message,
      });
      if (native == true) {
        debugPrint('PhoneService: system SMS sent');
        return true;
      }
    } catch (e) {
      debugPrint('PhoneService: native sendSms failed: $e');
    }

    // Fallback still goes to the system SMS app, never an in-app chat.
    return openSystemMessages(phoneNumber: sanitized);
  }

  /// Opens Android's default Messages app (optional thread for [phoneNumber]).
  Future<bool> openSystemMessages({String? phoneNumber}) async {
    try {
      final native = await _phoneChannel.invokeMethod<bool>(
        'openSystemMessages',
        {'number': phoneNumber},
      );
      if (native == true) return true;
    } catch (e) {
      debugPrint('PhoneService: openSystemMessages native failed: $e');
    }
    try {
      final data = phoneNumber == null || phoneNumber.isEmpty
          ? 'sms:'
          : 'sms:$phoneNumber';
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: data,
      );
      await intent.launch();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) return true;
    final result = await Permission.sms.request();
    return result.isGranted;
  }

  Future<List<SmsMessage>> readInboxMessages({int limit = 10}) async {
    try {
      final granted = await requestSmsPermission();
      if (!granted) return [];
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
      return messages.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> setSystemAlarm({
    required int hour,
    required int minute,
    String label = 'Voice Alarm',
  }) async {
    try {
      final native = await _alarmChannel.invokeMethod<bool>('setAlarm', {
        'hour': hour,
        'minute': minute,
        'label': label,
      });
      if (native == true) return true;
    } catch (e) {
      debugPrint('PhoneService: native setAlarm failed: $e');
    }

    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: <String, dynamic>{
          'android.intent.extra.alarm.HOUR': hour,
          'android.intent.extra.alarm.MINUTES': minute,
          'android.intent.extra.alarm.MESSAGE': label,
          'android.intent.extra.alarm.SKIP_UI': true,
        },
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('PhoneService: setSystemAlarm failed: $e');
      return false;
    }
  }

  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final already = await _phoneChannel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      if (already == true) return true;
      await _phoneChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      return true;
    } catch (e) {
      debugPrint('PhoneService: battery optimization request failed: $e');
      return false;
    }
  }

  Future<bool> addCalendarEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.INSERT',
        type: 'vnd.android.cursor.dir/event',
        arguments: <String, dynamic>{
          'title': title,
          if (description != null) 'description': description,
          'beginTime': start.millisecondsSinceEpoch,
          'endTime': end.millisecondsSinceEpoch,
        },
      );
      await intent.launch();
      return true;
    } catch (e) {
      return false;
    }
  }
}
