import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/models.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../routing/app_router.dart';
import '../../../../theme/app_theme.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  List<CalendarEvent> _events = [];
  bool _isLoading = true;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime? _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final repo = ref.read(localRepositoryProvider);
    final list = await repo.getEvents();
    setState(() {
      _events = list;
      _isLoading = false;
    });
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      if (!mounted) return;
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _saveEvent() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedDateTime == null) return;

    final repo = ref.read(localRepositoryProvider);
    final ev = CalendarEvent(
      id: const Uuid().v4(),
      title: title,
      description: _descController.text.trim(),
      dateTime: _selectedDateTime!,
      durationMinutes: 60,
      createdAt: DateTime.now(),
    );

    await repo.insertEvent(ev);
    _titleController.clear();
    _descController.clear();
    _selectedDateTime = null;
    Navigator.pop(context);
    _loadEvents();
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Meeting Event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Event Title'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await _pickDateTime();
                  setDialogState(() {});
                },
                icon: const Icon(Icons.date_range),
                label: Text(
                  _selectedDateTime == null 
                      ? 'Pick Date & Time' 
                      : DateFormat('MMM d, hh:mm a').format(_selectedDateTime!),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: _saveEvent,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar & Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_agenda_outlined),
            tooltip: 'Today\'s Agenda',
            onPressed: () => Navigator.pushNamed(context, AppRouter.dailyAgenda),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _showAddEventDialog,
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
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _events.isEmpty
                ? const Center(child: Text('No scheduled meetings.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final ev = _events[index];
                      final dateStr = DateFormat('EEEE, MMMM d').format(ev.dateTime);
                      final timeStr = DateFormat('hh:mm a').format(ev.dateTime);

                      return Card(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          onTap: () {
                            Navigator.pushNamed(
                              context, 
                              AppRouter.eventDetails, 
                              arguments: {'eventId': ev.id},
                            ).then((_) => _loadEvents());
                          },
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withValues(alpha: 0.1),
                            ),
                            child: const Icon(Icons.event, color: AppTheme.primary),
                          ),
                          title: Text(
                            ev.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('$dateStr at $timeStr'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
