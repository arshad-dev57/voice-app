import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tts_service.dart';

/// Centralised permission management for the voice assistant.
///
/// All critical permissions are requested upfront at app startup so blind
/// users do not encounter silent failures mid-interaction.
///
/// If any permission is denied, the assistant speaks clear feedback so the
/// user knows exactly what to do — without ever needing to look at the screen.
class PermissionService {
  static final PermissionService instance = PermissionService._init();
  PermissionService._init();

  // ---------------------------------------------------------------------- //
  //  Startup permission check                                                //
  // ---------------------------------------------------------------------- //

  /// Requests all permissions required for the assistant to function.
  ///
  /// Speaks voice feedback for any permission that is denied so blind users
  /// know they need to open settings and grant it.
  ///
  /// Returns true if ALL critical permissions (microphone, contacts, phone)
  /// are granted.
  Future<bool> requestAllCriticalPermissions({bool speakFeedback = true}) async {
    final results = await [
      Permission.microphone,
      Permission.contacts,
      Permission.phone,
      Permission.sms,
      Permission.notification,
    ].request();

    bool allCriticalGranted = true;
    final denied = <String>[];

    if (results[Permission.microphone] != PermissionStatus.granted) {
      allCriticalGranted = false;
      denied.add('microphone');
      debugPrint('PermissionService: microphone DENIED');
    }

    if (results[Permission.contacts] != PermissionStatus.granted) {
      allCriticalGranted = false;
      denied.add('contacts');
      debugPrint('PermissionService: contacts DENIED');
    }

    if (results[Permission.phone] != PermissionStatus.granted) {
      denied.add('phone calls');
      debugPrint('PermissionService: CALL_PHONE DENIED');
    }

    if (results[Permission.sms] != PermissionStatus.granted) {
      denied.add('send SMS');
      debugPrint('PermissionService: SEND_SMS DENIED');
    }

    if (denied.isNotEmpty && speakFeedback) {
      final list = denied.join(', ');
      await TtsService.instance.speak(
        'To work properly, I need permission to access: $list. '
        'Please open your phone settings and grant these permissions.',
      );
    }

    return allCriticalGranted;
  }

  // ---------------------------------------------------------------------- //
  //  Individual permission checks                                            //
  // ---------------------------------------------------------------------- //

  Future<bool> hasMicrophonePermission() async {
    return (await Permission.microphone.status).isGranted;
  }

  Future<bool> hasContactsPermission() async {
    return (await Permission.contacts.status).isGranted;
  }

  Future<bool> hasPhonePermission() async {
    return (await Permission.phone.status).isGranted;
  }

  Future<bool> hasSmsPermission() async {
    return (await Permission.sms.status).isGranted;
  }

  // ---------------------------------------------------------------------- //
  //  Speak-and-request pattern                                               //
  // ---------------------------------------------------------------------- //

  Future<bool> ensurePermission(
    Permission permission, {
    required String deniedMessage,
    bool requestIfDenied = true,
  }) async {
    var status = await permission.status;
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await TtsService.instance.speak(
        '$deniedMessage. '
        'This permission was permanently denied. '
        'Please open Settings and enable it manually.',
      );
      await openAppSettings();
      return false;
    }

    if (requestIfDenied) {
      status = await permission.request();
    }

    if (!status.isGranted) {
      await TtsService.instance.speak(deniedMessage);
      return false;
    }

    return true;
  }

  /// Ensures microphone permission with voice feedback.
  Future<bool> ensureMicrophonePermission() async {
    return ensurePermission(
      Permission.microphone,
      deniedMessage:
          'Microphone permission is required for voice commands. '
          'Please grant it to use the voice assistant.',
    );
  }

  /// Ensures contacts permission with voice feedback.
  Future<bool> ensureContactsPermission() async {
    return ensurePermission(
      Permission.contacts,
      deniedMessage:
          'Contacts permission is required to find and call your contacts. '
          'Please grant it in settings.',
    );
  }

  /// Ensures call phone permission with voice feedback.
  Future<bool> ensureCallPermission() async {
    return ensurePermission(
      Permission.phone,
      deniedMessage:
          'Phone call permission is required to place calls automatically. '
          'Please grant it in settings.',
    );
  }

  /// Ensures SMS send permission with voice feedback.
  Future<bool> ensureSmsPermission() async {
    return ensurePermission(
      Permission.sms,
      deniedMessage:
          'SMS permission is required to send messages automatically. '
          'Please grant it in settings.',
    );
  }
}

