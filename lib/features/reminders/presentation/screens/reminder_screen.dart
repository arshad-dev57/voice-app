import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/models.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../theme/app_theme.dart';

class ReminderScreen extends ConsumerStatefulWidget {
  const ReminderScreen({super.key});

  @override
  ConsumerState<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends ConsumerState<ReminderScreen> {
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, medicine, meeting, generic

  final TextEditingController _titleController = TextEditingController();
  String _selectedCategory = 'generic'; // generic, medicine, meeting
  DateTime? _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final repo = ref.read(localRepositoryProvider);
    final list = await repo.getReminders();
    setState(() {
      _reminders = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleReminder(Reminder reminder) async {
    final updated = Reminder(
      id: reminder.id,
      title: reminder.title,
      dateTime: reminder.dateTime,
      category: reminder.category,
      repeatType: reminder.repeatType,
      isCompleted: !reminder.isCompleted,
      createdAt: reminder.createdAt,
    );
    await ref.read(localRepositoryProvider).updateReminder(updated);
    _loadReminders();
  }

  Future<void> _deleteReminder(String id) async {
    await ref.read(localRepositoryProvider).deleteReminder(id);
    _loadReminders();
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
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

  Future<void> _addNewReminder() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedDateTime == null) return;

    final repo = ref.read(localRepositoryProvider);
    final reminder = Reminder(
      id: const Uuid().v4(),
      title: title,
      dateTime: _selectedDateTime!,
      category: _selectedCategory,
      repeatType: 'none',
      isCompleted: false,
      createdAt: DateTime.now(),
    );

    await repo.insertReminder(reminder);

    // Schedule notification trigger
    ref.read(notificationServiceProvider).scheduleNotification(
      id: reminder.id.hashCode,
      title: 'Reminder: ${_selectedCategory.toUpperCase()}',
      body: reminder.title,
      scheduledDate: reminder.dateTime,
    );

    _titleController.clear();
    _selectedDateTime = null;
    if (!mounted) return;
    Navigator.pop(context);
    _loadReminders();
  }

  void _showAddReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Reminder Title'),
              ),
              const SizedBox(height: 16),
              // Category chooser
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Category:'),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    items: ['generic', 'medicine', 'meeting'].map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat.toUpperCase()));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          _selectedCategory = val;
                        });
                        setState(() {
                          _selectedCategory = val;
                        });
                      }
                    },
                  ),
                ],
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
              onPressed: _addNewReminder,
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

    // Filter reminders
    final filteredList = _reminders.where((r) {
      if (_selectedFilter == 'all') return true;
      return r.category == _selectedFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddReminderDialog,
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
        child: Column(
          children: [
            // Filter Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'medicine', 'meeting', 'generic'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(filter.toUpperCase()),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Reminders List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredList.isEmpty
                      ? const Center(child: Text('No reminders found.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final rem = filteredList[index];
                            final dateStr = DateFormat('MMM d, hh:mm a').format(rem.dateTime);

                            return Card(
                              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                leading: IconButton(
                                  icon: Icon(
                                    rem.isCompleted
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: rem.isCompleted ? AppTheme.success : AppTheme.primary,
                                  ),
                                  onPressed: () => _toggleReminder(rem),
                                ),
                                title: Text(
                                  rem.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: rem.isCompleted ? TextDecoration.lineThrough : null,
                                    color: rem.isCompleted ? Colors.grey : null,
                                  ),
                                ),
                                subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        rem.category.toUpperCase(),
                                        style: const TextStyle(fontSize: 9, color: AppTheme.accent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                      onPressed: () => _deleteReminder(rem.id),
                                    ),
                                  ],
                                ),
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
