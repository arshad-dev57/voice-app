import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/models.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../theme/app_theme.dart';

class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> {
  List<Alarm> _alarms = [];
  bool _isLoading = true;
  final TextEditingController _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _loadAlarms() async {
    final repo = ref.read(localRepositoryProvider);
    final list = await repo.getAlarms();
    setState(() {
      _alarms = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleAlarm(Alarm alarm) async {
    final updated = Alarm(
      id: alarm.id,
      time: alarm.time,
      label: alarm.label,
      isEnabled: !alarm.isEnabled,
      repeatDays: alarm.repeatDays,
      createdAt: alarm.createdAt,
    );
    await ref.read(localRepositoryProvider).updateAlarm(updated);
    _loadAlarms();

    // Trigger local notification if enabled
    if (updated.isEnabled) {
      ref.read(notificationServiceProvider).showNotification(
        id: updated.id.hashCode,
        title: 'Alarm Enabled',
        body: 'Your alarm for ${updated.time} (${updated.label}) is now active.',
      );
    }
  }

  Future<void> _deleteAlarm(String id) async {
    await ref.read(localRepositoryProvider).deleteAlarm(id);
    _loadAlarms();
  }

  Future<void> _addNewAlarm() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      _labelController.clear();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Alarm Label'),
          content: TextField(
            controller: _labelController,
            decoration: const InputDecoration(hintText: 'e.g. Wake up, Prayer'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final label = _labelController.text.trim().isEmpty ? 'Alarm' : _labelController.text.trim();
                
                // Use AlarmService to set both local and system alarm
                final success = await ref.read(alarmServiceProvider).setAlarm(
                  hour: picked.hour,
                  minute: picked.minute,
                  label: label,
                  repeatDays: 'Mon,Tue,Wed,Thu,Fri',
                  repository: ref.read(localRepositoryProvider),
                );

                if (!mounted) return;
                Navigator.pop(context);
                _loadAlarms();
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alarm set in both app and system clock')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alarm set in app. Check system clock app.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('SAVE'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm),
            onPressed: () async {
              await ref.read(alarmServiceProvider).openSystemAlarmApp();
            },
            tooltip: 'Open System Clock',
          ),
          IconButton(
            icon: const Icon(Icons.add_alarm_rounded),
            onPressed: _addNewAlarm,
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
            : _alarms.isEmpty
                ? const Center(child: Text('No alarms set.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _alarms.length,
                    itemBuilder: (context, index) {
                      final alarm = _alarms[index];

                      return Card(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alarm.time,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: alarm.isEnabled
                                          ? AppTheme.primary
                                          : (isDark ? Colors.white60 : Colors.black45),
                                    ),
                                  ),
                                  Text(
                                    alarm.label,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    alarm.repeatDays,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Switch(
                                    value: alarm.isEnabled,
                                    onChanged: (_) => _toggleAlarm(alarm),
                                    activeThumbColor: AppTheme.primary,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                    onPressed: () => _deleteAlarm(alarm.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
