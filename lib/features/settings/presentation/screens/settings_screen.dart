import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../routing/app_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final settingsNotifier = ref.read(settingsControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
        child: settings.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Profile Section
                  Card(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                            child: const Icon(Icons.person, size: 36, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ref.read(authControllerProvider).currentUser?.name ?? 'Guest User',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                Text(
                                  ref.read(authControllerProvider).currentUser?.email ?? 'guest@smartassistant.ai',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('VOICE & HANDS-FREE'),
                  Card(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.vibration_outlined, color: AppTheme.primary),
                          title: const Text('Shake Phone to Activate'),
                          subtitle: const Text('Trigger microphone by shaking'),
                          trailing: Switch(
                            value: settings.shakeActivation,
                            onChanged: (val) => settingsNotifier.updateShakeActivation(val),
                            activeThumbColor: AppTheme.primary,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.record_voice_over, color: AppTheme.accent),
                          title: const Text('Wake-Word Engine'),
                          subtitle: const Text('Respond to "Hey Smart" / "Hello Assistant"'),
                          trailing: Switch(
                            value: settings.wakeWordEnabled,
                            onChanged: (val) => settingsNotifier.updateWakeWord(val),
                            activeThumbColor: AppTheme.primary,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.settings_voice, color: AppTheme.success),
                          title: const Text('Voice Customization'),
                          subtitle: const Text('Adjust speed and pitch'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(context, AppRouter.voiceSettings),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('GENERAL PREFERENCES'),
                  Card(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.language_rounded, color: AppTheme.primary),
                          title: const Text('Language Selection'),
                          subtitle: Text('Current: ${settings.language.toUpperCase()}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(context, AppRouter.languageSettings),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined, color: AppTheme.accent),
                          title: const Text('Notification Alerts'),
                          subtitle: const Text('Manage channel sounds & triggers'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(context, AppRouter.notificationSettings),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.brightness_medium_rounded, color: AppTheme.success),
                          title: const Text('Dark Mode Display'),
                          subtitle: const Text('Toggle between dark and light themes'),
                          trailing: Switch(
                            value: settings.theme == 'dark',
                            onChanged: (val) => settingsNotifier.updateTheme(val ? 'dark' : 'light'),
                            activeThumbColor: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionHeader('SECURITY & APP'),
                  Card(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.primary),
                          title: const Text('Privacy & Local Data'),
                          subtitle: const Text('Inspect offline records'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(context, AppRouter.securityPrivacy),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.info_outline_rounded, color: AppTheme.accent),
                          title: const Text('About Application'),
                          subtitle: const Text('Version, capabilities, developers'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(context, AppRouter.about),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Logout Button
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Log Out'),
                          content: const Text('Are you sure you want to log out? Offline features will remain active.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('CANCEL'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await ref.read(authControllerProvider.notifier).logout();
                                if (context.mounted) {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context, 
                                    AppRouter.login, 
                                    (route) => false,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                              child: const Text('LOG OUT'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('LOG OUT ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey),
      ),
    );
  }
}
