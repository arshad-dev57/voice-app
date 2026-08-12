import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:voice_recoginization_app/core/database/models.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/widgets/voice_orb.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/assistant_controller.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  late Timer _timer;
  String _timeString = '';
  String _dateString = '';

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) => _updateDateTime(),
    );

    // Shake is handled globally by AssistantController — do not overwrite it.
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateDateTime() {
    final DateTime now = DateTime.now();
    final String formattedTime = DateFormat('hh:mm:ss a').format(now);
    final String formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
    if (mounted) {
      setState(() {
        _timeString = formattedTime;
        _dateString = formattedDate;
      });
    }
  }

  String _getGreeting(String? name) {
    final hour = DateTime.now().hour;
    final userName = name ?? 'User';
    if (hour < 12) return 'Good Morning, $userName!';
    if (hour < 17) return 'Good Afternoon, $userName!';
    return 'Good Evening, $userName!';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Future providers
    final unreadCountAsync = ref.watch(unreadMessagesCountProvider);
    final remindersAsync = ref.watch(upcomingRemindersProvider);
    final eventsAsync = ref.watch(todayEventsProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.darkBg, const Color(0xFF141A24)]
                : [AppTheme.lightBg, const Color(0xFFE5ECF4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Dashboard header
              SliverPadding(
                padding: const EdgeInsets.all(24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(authState.currentUser?.name),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dateString,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        // Log out / settings avatar
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, AppRouter.settings),
                          child: CircleAvatar(
                            backgroundColor: AppTheme.primary.withValues(
                              alpha: 0.15,
                            ),
                            child: const Icon(
                              Icons.settings_rounded,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Floating Clock Widget
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: AppTheme.glassDecoration(
                        isDark: isDark,
                        opacity: 0.05,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _timeString,
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.0,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.primary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.wifi_rounded,
                                color: AppTheme.success,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Assistant Offline Mode Active',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Central glowing Assistant mic orb launcher
                    Center(
                      child: Column(
                        children: [
                          VoiceOrb(
                            state: OrbState.idle,
                            onTap: () {
                              Navigator.pushNamed(context, AppRouter.assistant);
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'TAP OR SHAKE TO TALK',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Quick Action Buttons
                    Text(
                      'QUICK ACTIONS',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        _quickActionButton(
                          context,
                          Icons.call,
                          'Call',
                          AppRouter.contacts,
                        ),
                        _quickActionButton(
                          context,
                          Icons.message,
                          'Chat',
                          AppRouter.messaging,
                        ),
                        _quickActionButton(
                          context,
                          Icons.alarm,
                          'Alarm',
                          AppRouter.alarms,
                        ),
                        _quickActionButton(
                          context,
                          Icons.calendar_month,
                          'Agenda',
                          AppRouter.calendar,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Unread message, Alarm, Schedule details
                    _buildUpcomingSchedule(context, eventsAsync, isDark),
                    const SizedBox(height: 16),
                    _buildUpcomingReminders(context, remindersAsync, isDark),
                    const SizedBox(height: 16),
                    _buildInboxSummary(context, unreadCountAsync, isDark),
                    const SizedBox(height: 30),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickActionButton(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => Navigator.pushNamed(context, route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: AppTheme.glassDecoration(isDark: isDark, opacity: 0.04),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSchedule(
    BuildContext context,
    AsyncValue<List<CalendarEvent>> events,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TODAY\'S AGENDA',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        events.when(
          data: (list) {
            if (list.isEmpty) {
              return _emptyCard(
                context,
                'No events scheduled for today.',
                Icons.calendar_today,
                isDark,
              );
            }
            return Column(
              children: list.map((ev) {
                final time = DateFormat('hh:mm a').format(ev.dateTime);
                return Card(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.02),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.event_note,
                      color: AppTheme.primary,
                    ),
                    title: Text(
                      ev.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(ev.description ?? 'No description'),
                    trailing: Text(
                      time,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) =>
              _errorCard(context, 'Failed to load schedule', isDark),
        ),
      ],
    );
  }

  Widget _buildUpcomingReminders(
    BuildContext context,
    AsyncValue<List<Reminder>> reminders,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'UPCOMING REMINDERS',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        reminders.when(
          data: (list) {
            if (list.isEmpty) {
              return _emptyCard(
                context,
                'No pending reminders.',
                Icons.check_circle_outline,
                isDark,
              );
            }
            return Column(
              children: list.map((rem) {
                final time = DateFormat('MMM d, hh:mm a').format(rem.dateTime);
                return Card(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.02),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      rem.category == 'medicine'
                          ? Icons.medication
                          : Icons.alarm,
                      color: AppTheme.accent,
                    ),
                    title: Text(
                      rem.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(time),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rem.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) =>
              _errorCard(context, 'Failed to load reminders', isDark),
        ),
      ],
    );
  }

  Widget _buildInboxSummary(
    BuildContext context,
    AsyncValue<int> count,
    bool isDark,
  ) {
    return count.when(
      data: (unread) {
        return InkWell(
          onTap: () => Navigator.pushNamed(context, AppRouter.messaging),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassDecoration(isDark: isDark, opacity: 0.05),
            child: Row(
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unread Messages Summary',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        unread == 0
                            ? 'All messages read.'
                            : 'You have $unread active conversations.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _emptyCard(
    BuildContext context,
    String message,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(isDark: isDark, opacity: 0.02),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey.withValues(alpha: 0.5), size: 32),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context, String message, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.error, fontSize: 13),
      ),
    );
  }
}
