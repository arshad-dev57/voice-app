import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/local_repository.dart';
import '../database/models.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/notification_service.dart';
import '../services/shake_service.dart';
import '../services/firebase_service.dart';
import '../services/contacts_service.dart';
import '../services/phone_service.dart';

final localRepositoryProvider = Provider<LocalRepository>((ref) {
  return LocalRepository();
});

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService.instance;
});

final contactsServiceProvider = Provider<ContactsService>((ref) {
  return ContactsService.instance;
});

final phoneServiceProvider = Provider<PhoneService>((ref) {
  return PhoneService.instance;
});

final speechServiceProvider = Provider<SpeechService>((ref) {
  return SpeechService.instance;
});

final ttsServiceProvider = Provider<TtsService>((ref) {
  return TtsService.instance;
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final shakeServiceProvider = Provider<ShakeService>((ref) {
  return ShakeService.instance;
});

// Future Providers for Dashboard data
final unreadMessagesCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(localRepositoryProvider);
  final convs = await repo.getConversations();
  // Simply mock the number of unread conversations or do database sum
  return convs.length; // return count of threads for simplicity
});

final upcomingRemindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final repo = ref.watch(localRepositoryProvider);
  final reminders = await repo.getReminders();
  final now = DateTime.now();
  return reminders
      .where((r) => !r.isCompleted && r.dateTime.isAfter(now))
      .take(3)
      .toList();
});

final todayEventsProvider = FutureProvider<List<CalendarEvent>>((ref) async {
  final repo = ref.watch(localRepositoryProvider);
  final events = await repo.getEvents();
  final now = DateTime.now();
  // Filter for today's events
  return events.where((e) {
    return e.dateTime.year == now.year &&
        e.dateTime.month == now.month &&
        e.dateTime.day == now.day;
  }).toList();
});
