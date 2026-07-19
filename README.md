# Smart Voice Assistant

A Flutter voice assistant that lets you control your phone with voice commands —
calling, messaging, reminders, alarms, and calendar scheduling — with English,
Urdu, and Roman Urdu support and offline-first local storage.

## Tech stack

- Flutter (Dart), Material 3
- Riverpod for state management
- SQLite (`sqflite`) + `shared_preferences` for local/offline storage
- `speech_to_text` for on-device speech recognition
- `flutter_tts` for text-to-speech (English + Urdu voices)
- `flutter_local_notifications` + `timezone` for alarms/reminders
- `sensors_plus` for shake-to-activate
- `url_launcher` for launching the native dialer
- `permission_handler` for runtime permissions

## Project structure

```
lib/
  main.dart                 App entry point (ProviderScope + router + theme)
  core/
    database/               SQLite database, models, repository
    providers/              Riverpod providers wiring services together
    services/               speech, tts, notifications, shake, nlp_engine
  features/
    auth/                   splash, login/signup (local mock auth)
    onboarding/             intro slides, language + permission setup
    assistant/              home dashboard, voice assistant screen, controller
    calling/                call management screen
    contacts/               contacts list
    messaging/              conversations + chat detail
    alarms/                 alarm list
    reminders/              reminder list
    calendar/               calendar, agenda, event details
    settings/               settings + sub-screens
  routing/app_router.dart   Named routes
  shared/widgets/           Shared UI (voice orb)
  theme/app_theme.dart      Colors, gradients, light/dark themes
```

## Getting started

1. Install Flutter (SDK `^3.12.2`) and set up an Android device/emulator.
2. Install dependencies:
   ```
   flutter pub get
   ```
3. Run the app:
   ```
   flutter run
   ```
4. Build a release APK:
   ```
   flutter build apk --release
   ```
   The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

## Permissions required (Android)

Declared in `android/app/src/main/AndroidManifest.xml`:

- `RECORD_AUDIO` — speech recognition
- `INTERNET` — future online sync / cloud STT
- `READ_CONTACTS`, `WRITE_CONTACTS` — contact matching
- `CALL_PHONE` — placing calls
- `SEND_SMS`, `READ_SMS`, `RECEIVE_SMS` — messaging
- `VIBRATE`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED` — notifications/alarms
- `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `POST_NOTIFICATIONS` — scheduled alerts

The app requests microphone and notification permissions at runtime during onboarding.

## How to use

1. Launch → splash → onboarding slides → language selection → permission setup.
2. Log in or sign up (see note on auth below).
3. On the home dashboard, tap the glowing mic orb or shake the phone to open the
   assistant. It starts listening automatically. You can also type a command.
4. Example commands (English / Roman Urdu):
   - "Hello" / "Assalam u alaikum"
   - "What time is it" / "Time kya hai"
   - "Call Ali" / "Ali ko call karo"
   - "Text Ali I am coming" / "Ali ko message karo I am coming"
   - "Set alarm for 7 am" / "Alarm laga do 7 baje"
   - "Remind me to take medicine at 9 pm"
   - "What is my schedule today" / "Next meeting"
   - "Open settings" / "Show reminders"
5. The assistant asks for confirmation ("Do you want to…?"). Reply
   "Yes/Haan/Ji" or "No/Nahi/Cancel". Responses are spoken aloud and the orb
   color reflects state (idle/listening/processing/responding).

## Notes and known issues

This is a strong offline prototype. The following items from the original spec
are intentionally simplified or still require your setup, so they are documented
honestly rather than faked:

- Authentication is local/mock. Login/signup creates a user in the local SQLite
  database (no server verification). Any valid-looking email + 6+ char password
  works. There is no Firebase Auth.
- Firebase + Firestore is not integrated. Storage is SQLite-only. Adding cloud
  sync requires creating a Firebase project, running `flutterfire configure`,
  adding `firebase_core`/`cloud_firestore`, and placing `google-services.json`
  under `android/app/`. This needs your own Firebase account.
- Calling launches the native dialer via the `tel:` scheme (works on a real
  device). The in-app call screen is a UI/timer simulation on top of that.
- SMS sending is stored locally only; native SMS send/read is not wired up.
  Real SMS requires a platform channel or an SMS plugin and must be tested on a
  physical device (SEND_SMS/READ_SMS are already declared).
- Contacts come from the local database, not the phone's real contact list.
  Add real contacts support with a contacts plugin (e.g. `flutter_contacts`).
- Multilingual support: voice intent parsing handles English/Urdu/Roman Urdu
  keywords and TTS switches voice by selected language. UI strings are not yet
  externalized into `en.json`/`ur.json`/`roman_ur.json` localization files.
- Wake-word ("Hello Assistant") continuous listening is not implemented;
  activation is by tapping the orb or shaking the phone.
- Local data is stored unencrypted. For the privacy requirement, add an
  encrypted store (e.g. `sqlcipher`/`flutter_secure_storage`).

## Features that need a real device to test

Calling, SMS, and shake/gesture controls do not work fully on emulators — test
them on a physical Android phone.
