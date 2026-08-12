import 'package:flutter/material.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/onboarding/presentation/screens/language_selection_screen.dart';
import '../features/onboarding/presentation/screens/permission_setup_screen.dart';
import '../features/assistant/presentation/screens/home_dashboard_screen.dart';
import '../features/assistant/presentation/screens/voice_assistant_screen.dart';
import '../features/assistant/presentation/screens/activity_history_screen.dart';
import '../features/calling/presentation/screens/call_management_screen.dart';
import '../features/contacts/presentation/screens/contacts_screen.dart';
import '../features/alarms/presentation/screens/alarm_screen.dart';
import '../features/reminders/presentation/screens/reminder_screen.dart';
import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/calendar/presentation/screens/event_details_screen.dart';
import '../features/calendar/presentation/screens/daily_agenda_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/settings/presentation/screens/language_settings_screen.dart';
import '../features/settings/presentation/screens/voice_settings_screen.dart';
import '../features/settings/presentation/screens/security_privacy_screen.dart';
import '../features/settings/presentation/screens/notification_settings_screen.dart';
import '../features/settings/presentation/screens/about_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String languageSelect = '/language-select';
  static const String permissionSetup = '/permission-setup';
  static const String login = '/login';
  static const String home = '/home';
  static const String assistant = '/assistant';
  static const String dashboard = '/dashboard';
  static const String activityHistory = '/activity-history';
  static const String callManagement = '/call-management';
  static const String contacts = '/contacts';
  static const String alarms = '/alarms';
  static const String reminders = '/reminders';
  static const String calendar = '/calendar';
  static const String eventDetails = '/event-details';
  static const String dailyAgenda = '/daily-agenda';
  static const String settings = '/settings';
  static const String languageSettings = '/language-settings';
  static const String voiceSettings = '/voice-settings';
  static const String securityPrivacy = '/security-privacy';
  static const String notificationSettings = '/notification-settings';
  static const String about = '/about';

  static Route<dynamic> generateRoute(RouteSettings settingsVal) {
    switch (settingsVal.name) {
      case splash:
        return _buildRoute(const SplashScreen());
      case onboarding:
        return _buildRoute(const OnboardingScreen());
      case languageSelect:
        return _buildRoute(const LanguageSelectionScreen());
      case permissionSetup:
        return _buildRoute(const PermissionSetupScreen());
      case login:
        return _buildRoute(const LoginScreen());
      case home:
        return _buildRoute(const VoiceAssistantScreen());
      case assistant:
        return _buildRoute(const VoiceAssistantScreen());
      case dashboard:
        return _buildRoute(const HomeDashboardScreen());
      case activityHistory:
        return _buildRoute(const ActivityHistoryScreen());
      case callManagement:
        final args = settingsVal.arguments as Map<String, dynamic>?;
        return _buildRoute(CallManagementScreen(
          contactName: args?['contactName'] ?? '',
          phoneNumber: args?['phoneNumber'] ?? '',
          incoming: args?['incoming'] ?? false,
        ));
      case contacts:
        return _buildRoute(const ContactsScreen());
      case alarms:
        return _buildRoute(const AlarmScreen());
      case reminders:
        return _buildRoute(const ReminderScreen());
      case calendar:
        return _buildRoute(const CalendarScreen());
      case eventDetails:
        final args = settingsVal.arguments as Map<String, dynamic>?;
        return _buildRoute(EventDetailsScreen(
          eventId: args?['eventId'] ?? '',
        ));
      case dailyAgenda:
        return _buildRoute(const DailyAgendaScreen());
      case settings:
        return _buildRoute(const SettingsScreen());
      case languageSettings:
        return _buildRoute(const LanguageSettingsScreen());
      case voiceSettings:
        return _buildRoute(const VoiceSettingsScreen());
      case securityPrivacy:
        return _buildRoute(const SecurityPrivacyScreen());
      case notificationSettings:
        return _buildRoute(const NotificationSettingsScreen());
      case about:
        return _buildRoute(const AboutScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settingsVal.name}'),
            ),
          ),
        );
    }
  }

  static PageRouteBuilder _buildRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.05);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        var fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeIn),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
