import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'core/services/alarm_service.dart';
import 'firebase_options.dart';

import 'features/settings/presentation/controllers/settings_controller.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase. Wrapped in try/catch so the app still runs offline
  // (SQLite is the source of truth) even if Firebase init fails.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed (continuing offline): $e');
  }

  // Initialize local notifications (timezones etc.) before the app starts.
  await NotificationService.instance.initialize();

  // Initialize alarm service for background alarm support
  await AlarmService.initialize();

  runApp(const ProviderScope(child: SmartVoiceAssistantApp()));
}

class SmartVoiceAssistantApp extends ConsumerWidget {
  const SmartVoiceAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings so theme reacts to user preference (light/dark).
    final settings = ref.watch(settingsControllerProvider);
    final themeMode = settings.theme == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;

    // Map language code to Locale
    Locale getLocale(String languageCode) {
      switch (languageCode) {
        case 'ur':
          return const Locale('ur');
        case 'roman_ur':
          return const Locale('en'); // Roman Urdu uses English locale for UI
        case 'en':
        default:
          return const Locale('en');
      }
    }

    return MaterialApp(
      title: 'Smart Voice Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: getLocale(settings.language),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
      ],
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
