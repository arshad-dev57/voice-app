import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

import 'features/settings/presentation/controllers/settings_controller.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

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

    return MaterialApp(
      title: 'Smart Voice Assistant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
