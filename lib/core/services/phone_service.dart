import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bridges the assistant to the phone's real capabilities:
///  - Sending real SMS text messages
///  - Making real phone calls using the native dialer
///  - Setting a real system alarm (the phone's Clock app)
///  - Adding events to the phone's real calendar
///
/// These use Android platform intents / telephony APIs rather than the
/// in-app mock database, so actions actually happen on the device.
class PhoneService {
  static final PhoneService instance = PhoneService._init();
  PhoneService._init();

  final Telephony _telephony = Telephony.instance;
  static const _accessibilityChannel = MethodChannel('com.example.voice_recoginization_app/accessibility');

  // ---------------------------------------------------------------------------
  // DUAL SIM DETECTION
  // ---------------------------------------------------------------------------

  /// Maps common SIM carrier names to slot indices
  /// Users can say "Zong", "Jazz", "SIM 1", "SIM 2", etc.
  int? getSimSlotFromName(String simName) {
    final lowerName = simName.toLowerCase().trim();
    
    // Map common carrier names to slot indices
    if (lowerName.contains('zong') || lowerName.contains('sim 1') || lowerName.contains('first') || lowerName.contains('one')) {
      return 0; // SIM 1
    } else if (lowerName.contains('jazz') || lowerName.contains('telenor') || lowerName.contains('ufone') || 
               lowerName.contains('sim 2') || lowerName.contains('second') || lowerName.contains('two')) {
      return 1; // SIM 2
    }
    
    // Try to parse as number
    if (lowerName.contains('1')) return 0;
    if (lowerName.contains('2')) return 1;
    
    debugPrint('PhoneService: Could not determine SIM slot for "$simName"');
    return null;
  }

  /// Sets the target SIM for accessibility service to auto-select
  Future<void> setTargetSim(String simName) async {
    try {
      await _accessibilityChannel.invokeMethod('setTargetSim', {'simName': simName});
      debugPrint('PhoneService: Set target SIM to $simName via accessibility service');
    } catch (e) {
      debugPrint('PhoneService: Failed to set target SIM: $e');
    }
  }

  /// Checks if accessibility service is enabled
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result = await _accessibilityChannel.invokeMethod('isAccessibilityServiceEnabled');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('PhoneService: Failed to check accessibility service: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // PHONE CALL (native dialer)
  // ---------------------------------------------------------------------------

  /// Makes a real phone call using the device's native dialer app.
  ///
  /// Uses CALL action for auto-dialing (requires CALL_PHONE permission).
  /// Falls back to DIAL if CALL fails.
  /// Returns true if the call was initiated successfully.
  Future<bool> makePhoneCall({
    required String phoneNumber,
    int? simSlot, // 0 for SIM1, 1 for SIM2 (for dual SIM devices)
  }) async {
    try {
      // Request CALL_PHONE permission
      final granted = await _requestCallPermission();
      if (!granted) {
        debugPrint('PhoneService: CALL_PHONE permission denied');
        // Fallback to DIAL which doesn't require special permission
        final sanitizedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
        return await _launchDialerIntent(sanitizedNumber);
      }
      
      // Sanitize phone number: remove spaces, dashes, parentheses, etc.
      final sanitizedNumber = phoneNumber.replaceAll(
        RegExp(r'[^\d+]'),
        '',
      );
      
      if (sanitizedNumber.isEmpty) {
        debugPrint('PhoneService: Phone number is empty after sanitization');
        return false;
      }

      debugPrint('PhoneService: Auto-dialing $sanitizedNumber on SIM ${simSlot ?? 'default'} (original: $phoneNumber)');
      
      // Note: Programmatic SIM selection via intent extras is not reliably supported
      // across all Android versions and manufacturers due to security restrictions.
      // The system may still show a SIM selection dialog regardless of the extras.
      // For full automation, users should set a default SIM in Android settings.
      
      // Try CALL action first for auto-dialing
      final callSuccess = await _launchCallIntent(sanitizedNumber, simSlot);
      if (callSuccess) {
        return true;
      }
      
      // Fallback to DIAL action if CALL fails
      debugPrint('PhoneService: CALL failed, trying DIAL fallback');
      return await _launchDialerIntent(sanitizedNumber);
    } catch (e) {
      debugPrint('PhoneService: makePhoneCall failed: $e');
      // Try fallback on error
      final sanitizedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      return await _launchDialerIntent(sanitizedNumber);
    }
  }

  /// Request CALL_PHONE permission
  Future<bool> _requestCallPermission() async {
    try {
      final status = await Permission.phone.status;
      if (status.isGranted) return true;
      final result = await Permission.phone.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('PhoneService: Error requesting CALL_PHONE permission: $e');
      return false;
    }
  }

  /// Launch CALL intent for auto-dialing (requires CALL_PHONE permission)
  Future<bool> _launchCallIntent(String phoneNumber, int? simSlot) async {
    try {
      final arguments = <String, dynamic>{
        'android.intent.extra.PHONE_NUMBER': phoneNumber,
      };
      
      // Add SIM slot for dual SIM devices
      // Different manufacturers use different extras for SIM selection
      if (simSlot != null) {
        // Try multiple possible extras for SIM selection across different Android versions
        // Slot index approach (works on some devices)
        arguments['com.android.phone.extra.slot'] = simSlot;
        arguments['slot'] = simSlot;
        
        // Subscription ID approach (more reliable on newer Android)
        arguments['android.intent.extra.SUBSCRIPTION'] = simSlot;
        arguments['android.intent.extra.SUBSCRIPTION'] = simSlot.toString();
        
        // Manufacturer-specific extras
        arguments['com.android.phone.extra.SUBSCRIPTION'] = simSlot;
        arguments['com.android.phone.extra.SUBSCRIPTION'] = simSlot.toString();
        arguments['com.samsung.android.telephony.extra.SUBSCRIPTION'] = simSlot;
        
        // Alternative keys used by some OEMs
        arguments['simId'] = simSlot;
        arguments['sim_slot'] = simSlot;
        
        debugPrint('PhoneService: Added SIM slot $simSlot to CALL intent with multiple extras');
      }

      final intent = AndroidIntent(
        action: 'android.intent.action.CALL',
        data: 'tel:$phoneNumber',
        arguments: arguments,
      );
      await intent.launch();
      debugPrint('PhoneService: Call initiated via CALL action');
      return true;
    } catch (e) {
      debugPrint('PhoneService: CALL intent failed: $e');
      return false;
    }
  }

  /// Fallback method using DIAL intent (opens dialer, doesn't auto-call)
  Future<bool> _launchDialerIntent(String phoneNumber) async {
    try {
      final intent = AndroidIntent(
        action: 'android.intent.action.DIAL',
        data: 'tel:$phoneNumber',
      );
      await intent.launch();
      debugPrint('PhoneService: Dialer launched via DIAL action');
      return true;
    } catch (e) {
      debugPrint('PhoneService: DIAL intent failed: $e');
      return false;
    }
  }

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
