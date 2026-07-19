import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/models.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../theme/app_theme.dart';

class DailyAgendaScreen extends ConsumerStatefulWidget {
  const DailyAgendaScreen({super.key});

  @override
  ConsumerState<DailyAgendaScreen> createState() => _DailyAgendaScreenState();
}

class _DailyAgendaScreenState extends ConsumerState<DailyAgendaScreen> {
  List<CalendarEvent> _todayEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayEvents();
  }

  Future<void> _loadTodayEvents() async {
    final repo = ref.read(localRepositoryProvider);
    final events = await repo.getEvents();
    final now = DateTime.now();

    final filtered = events.where((e) {
      return e.dateTime.year == now.year &&
             e.dateTime.month == now.month &&
             e.dateTime.day == now.day;
    }).toList();

    setState(() {
      _todayEvents = filtered;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayString = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Agenda'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [AppTheme.darkBg, const Color(0xFF141923)] 
                : [AppTheme.lightBg, const Color(0xFFE6EDF5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              todayString,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _todayEvents.isEmpty
                      ? const Center(child: Text('No events on your calendar for today.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _todayEvents.length,
                          itemBuilder: (context, index) {
                            final ev = _todayEvents[index];
                            final time = DateFormat('hh:mm a').format(ev.dateTime);

                            return IntrinsicHeight(
                              child: Row(
                                children: [
                                  // Timeline bubble line indicator
                                  Column(
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: AppTheme.primaryGradient,
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: AppTheme.primary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 20),

                                  // Event details card
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 24.0),
                                      child: Card(
                                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                                        elevation: 0,
                                        margin: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    ev.title,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  Text(
                                                    time,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (ev.description != null && ev.description!.isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  ev.description!,
                                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
