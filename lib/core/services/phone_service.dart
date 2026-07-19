import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bridges the assistant to the phone's real capabilities:
///  - Sending real SMS text messages
///  - Setting a real system alarm (the phone's Clock app)
///  - Adding events to the phone's real calendar
///
/// These use Android platform intents / telephony APIs rather than the
/// in-app mock database, so actions actually happen on the device.
class PhoneService {
  static final PhoneService instance = PhoneService._init();
  PhoneService._init();

  final Telephony _telephony = Telephony.instance;

  // ---------------------------------------------------------------------------
  // SMS
  // ---------------------------------------------------------------------------

  /// Sends a real SMS to [phoneNumber] with [message].
  ///
  /// Returns true if the send was dispatched. Requires SEND_SMS permission.
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final granted = await requestSmsPermission();
      if (!granted) {
        debugPrint('PhoneService: SMS permission denied.');
        return false;
      }
      await _telephony.sendSms(to: phoneNumber, message: message);
      return true;
    } catch (e) {
      debugPrint('PhoneService: sendSms failed: $e');
      // Fallback: open the default SMS app pre-filled so the user can send.
      return _openSmsComposer(phoneNumber, message);
    }
  }

  Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) return true;
    final result = await Permission.sms.request();
    return result.isGranted;
  }

  /// Opens the system SMS composer as a fallback when direct send is blocked.
  Future<bool> _openSmsComposer(String phoneNumber, String message) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SENDTO',
        data: 'smsto:$phoneNumber',
        arguments: <String, dynamic>{'sms_body': message},
      );
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('PhoneService: openSmsComposer failed: $e');
      return false;
    }
  }

  /// Reads the most recent inbox SMS messages from the phone.
  Future<List<SmsMessage>> readInboxMessages({int limit = 10}) async {
    try {
      final granted = await _requestReadSmsPermission();
      if (!granted) return [];
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );
      return messages.take(limit).toList();
    } catch (e) {
      debugPrint('PhoneService: readInboxMessages failed: $e');
      return [];
    }
  }

  Future<bool> _requestReadSmsPermission() async {
    final status = await Permission.sms.status;
    if (status.isGranted) return true;
    final result = await Permission.sms.request();
    return result.isGranted;
  }

  // ---------------------------------------------------------------------------
  // ALARM (real system Clock app)
  // ---------------------------------------------------------------------------

  /// Sets a real alarm in the phone's Clock app for [hour]:[minute] (24h).
  ///
  /// Uses the AlarmClock.ACTION_SET_ALARM intent, which every Android Clock
  /// app implements. Returns true if the intent was launched.
  Future<bool> setSystemAlarm({
    required int hour,
    required int minute,
    String label = 'Voice Alarm',
  }) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: <String, dynamic>{
          'android.intent.extra.alarm.HOUR': hour,
          'android.intent.extra.alarm.MINUTES': minute,
          'android.intent.extra.alarm.MESSAGE': label,
          // Don't force the UI; set it silently when possible.
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

  // ---------------------------------------------------------------------------
  // CALENDAR (real device calendar)
  // ---------------------------------------------------------------------------

  /// Adds an event to the phone's real calendar via the Insert intent.
  ///
  /// [start] and [end] are the event window. Returns true if launched.
  Future<bool> addCalendarEvent({
    required String title,
    required DateTime start,
    required DateTime end,
    String? description,
  }) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.INSERT',
        // com.android.calendar Events content type
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
      debugPrint('PhoneService: addCalendarEvent failed: $e');
      return false;
    }
  }
}
