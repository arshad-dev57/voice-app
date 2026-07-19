import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/models.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../theme/app_theme.dart';

class EventDetailsScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailsScreen({
    super.key,
    required this.eventId,
  });

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  CalendarEvent? _event;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    final repo = ref.read(localRepositoryProvider);
    final events = await repo.getEvents();
    final matched = events.where((e) => e.id == widget.eventId);

    setState(() {
      if (matched.isNotEmpty) {
        _event = matched.first;
      }
      _isLoading = false;
    });
  }

  Future<void> _deleteEvent() async {
    if (_event != null) {
      await ref.read(localRepositoryProvider).deleteEvent(_event!.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event Details')),
        body: const Center(child: Text('Event not found.')),
      );
    }

    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(_event!.dateTime);
    final timeStr = DateFormat('hh:mm a').format(_event!.dateTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.error),
            onPressed: _deleteEvent,
          ),
        ],
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: AppTheme.glassDecoration(isDark: isDark, opacity: 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _event!.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppTheme.primary),
                      const SizedBox(width: 12),
                      Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time_filled, color: AppTheme.accent),
                      const SizedBox(width: 12),
                      Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.timelapse_rounded, color: AppTheme.success),
                      const SizedBox(width: 12),
                      Text('${_event!.durationMinutes} Minutes Duration', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (_event!.description != null && _event!.description!.isNotEmpty) ...[
                    const Divider(height: 32),
                    const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      _event!.description!,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
