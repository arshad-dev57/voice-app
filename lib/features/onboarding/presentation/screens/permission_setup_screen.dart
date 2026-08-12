import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../theme/app_theme.dart';
import '../../../../routing/app_router.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class PermissionItem {
  final String title;
  final String description;
  final IconData icon;
  final Permission permission;
  bool isGranted;

  PermissionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.permission,
    this.isGranted = false,
  });
}

class PermissionSetupScreen extends ConsumerStatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  ConsumerState<PermissionSetupScreen> createState() =>
      _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends ConsumerState<PermissionSetupScreen> {
  final List<PermissionItem> _permissionItems = [
    PermissionItem(
      title: 'Microphone Access',
      description: 'Required to record and process your speech queries.',
      icon: Icons.mic_rounded,
      permission: Permission.microphone,
    ),
    PermissionItem(
      title: 'Contacts Directory',
      description: 'Used to match names (like "Mom" or "Ali") for calling and texting.',
      icon: Icons.contact_phone_rounded,
      permission: Permission.contacts,
    ),
    PermissionItem(
      title: 'Phone Dialing',
      description: 'Needed to execute voice-activated phone calls.',
      icon: Icons.call_rounded,
      permission: Permission.phone,
    ),
    PermissionItem(
      title: 'SMS Service',
      description: 'Allows reading out incoming texts and sending SMS updates.',
      icon: Icons.textsms_rounded,
      permission: Permission.sms,
    ),
    PermissionItem(
      title: 'Push Notifications',
      description: 'Enables timed alerts for alarms and reminder schedules.',
      icon: Icons.notifications_active_rounded,
      permission: Permission.notification,
    ),
    PermissionItem(
      title: 'Calendar Planner',
      description: 'Allows reading, adding, and scheduling your calendar meetings.',
      icon: Icons.calendar_today_rounded,
      permission: Permission.calendarFullAccess,
    ),
    PermissionItem(
      title: 'Run in Background',
      description: 'Keeps shake-to-talk working when the screen is off.',
      icon: Icons.battery_saver_rounded,
      permission: Permission.ignoreBatteryOptimizations,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    for (var item in _permissionItems) {
      final status = await item.permission.status;
      setState(() {
        item.isGranted = status.isGranted;
      });
    }
  }

  Future<void> _requestPermission(PermissionItem item) async {
    final status = await item.permission.request();
    setState(() {
      item.isGranted = status.isGranted;
    });
  }

  Future<void> _requestAllPermissions() async {
    for (var item in _permissionItems) {
      if (!item.isGranted) {
        await _requestPermission(item);
      }
    }
  }

  Future<void> _finishSetup() async {
    final repo = ref.read(localRepositoryProvider);
    await repo.saveSetting('onboarding_complete', 'true');
    await ref.read(authControllerProvider.notifier).continueAsGuest();
    try {
      await ref.read(phoneServiceProvider).requestIgnoreBatteryOptimizations();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
        centerTitle: true,
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
              'Secure Your Operations',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'To run voice assistant tasks directly, please grant the following permissions. The assistant works offline and respects your privacy.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                itemCount: _permissionItems.length,
                itemBuilder: (context, index) {
                  final item = _permissionItems[index];

                  return Card(
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.04) 
                        : Colors.black.withValues(alpha: 0.03),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.08) 
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: item.isGranted
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.primary.withValues(alpha: 0.1),
                        child: Icon(
                          item.icon,
                          color: item.isGranted ? AppTheme.success : AppTheme.primary,
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      trailing: item.isGranted
                          ? const Icon(Icons.check_circle, color: AppTheme.success)
                          : ElevatedButton(
                              onPressed: () => _requestPermission(item),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Grant', style: TextStyle(fontSize: 12)),
                            ),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _finishSetup(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('SKIP FOR NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _requestAllPermissions();
                      await _finishSetup();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('GRANT ALL', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
