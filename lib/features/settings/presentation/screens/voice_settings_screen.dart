import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/app_theme.dart';
import '../controllers/settings_controller.dart';

class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Customization')),
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
            const Text(
              'Speech Synthesis Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Customize the voice assistant feedback rate and tone settings below.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 40),

            // Speech Rate Slider
            Text(
              'SPEECH RATE: ${settings.speechRate.toStringAsFixed(1)}x',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
            Slider(
              value: settings.speechRate,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              thumbColor: AppTheme.primary,
              onChanged: (val) => notifier.updateSpeechRate(val),
            ),
            const SizedBox(height: 30),

            // Speech Pitch Slider
            Text(
              'SPEECH PITCH: ${settings.speechPitch.toStringAsFixed(1)}x',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
            Slider(
              value: settings.speechPitch,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              thumbColor: AppTheme.accent,
              onChanged: (val) => notifier.updateSpeechPitch(val),
            ),
            const SizedBox(height: 40),

            Card(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : Colors.black.withValues(alpha: 0.01),
              elevation: 0,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Note: Speech synthesis changes will take effect during the assistant\'s next vocal response.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
