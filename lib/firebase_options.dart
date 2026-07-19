// File generated to configure Firebase for the Smart Voice Assistant app.
// Values are derived from android/app/google-services.json.
//
// NOTE: Only the Android platform is configured here because Firebase was set
// up for Android. If you later add iOS/web/etc., run `flutterfire configure`
// to regenerate this file with the additional platforms.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions has not been configured for web - '
        'reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for '
          '$defaultTargetPlatform - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCJb-tArZfLDLtDdRsGSvM_qqbUv1Wf-CQ',
    appId: '1:340010902307:android:d637fa3919d07852d26296',
    messagingSenderId: '340010902307',
    projectId: 'voice-a8fe2',
    storageBucket: 'voice-a8fe2.firebasestorage.app',
  );
}
