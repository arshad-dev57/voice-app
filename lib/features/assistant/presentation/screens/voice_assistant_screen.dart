import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/widgets/voice_orb.dart';
import '../../../../theme/app_theme.dart';
import '../../../../core/services/shake_detection_service.dart';
import '../../../../core/providers/core_providers.dart';
import '../controllers/assistant_controller.dart';

class VoiceAssistantScreen extends ConsumerStatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  ConsumerState<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends ConsumerState<VoiceAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _backgroundModeEnabled = false;

  @override
  void initState() {
    super.initState();
    ShakeDetectionService.initialize();
    // Auto start listening on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Speak initial greeting for blind users
      final tts = ref.read(ttsServiceProvider);
      await tts.speak('Hello! Press the mic or shake your phone to speak.');
      ref.read(assistantControllerProvider.notifier).toggleListening();
    });
  }

  void _toggleBackgroundMode() {
    setState(() {
      _backgroundModeEnabled = !_backgroundModeEnabled;
      if (_backgroundModeEnabled) {
        ShakeDetectionService.startDetection();
      } else {
        ShakeDetectionService.stopDetection();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendManualText() {
    final query = _textController.text.trim();
    if (query.isNotEmpty) {
      ref.read(assistantControllerProvider.notifier).processSpokenText(query);
      _textController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen for navigation requests from the AI Assistant
    ref.listen(assistantControllerProvider, (previous, next) {
      if (next.navigationTarget != null) {
        final target = next.navigationTarget!;
        ref.read(assistantControllerProvider.notifier).clearNavigation();
        
        if (target == AppRouter.callManagement) {
          // Pass arguments for Call Screen
          final name = next.pendingIntent?.contactName ?? 'Someone';
          final phone = next.pendingIntent?.messageText ?? '';
          Navigator.pushNamed(context, target, arguments: {
            'contactName': name,
            'phoneNumber': phone,
            'incoming': false,
          });
        } else {
          Navigator.pushNamed(context, target);
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Voice Assistant'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _backgroundModeEnabled ? Icons.sensors : Icons.sensors_off,
              color: _backgroundModeEnabled ? AppTheme.success : null,
            ),
            tooltip: 'Background Shake Detection',
            onPressed: _toggleBackgroundMode,
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.pushNamed(context, AppRouter.activityHistory),
          ),
        ],
      ),
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
        child: Column(
          children: [
            // Top Section: Transcript & Assistant Response
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Transcript box
                    if (state.transcript.isNotEmpty)
                      Center(
                        child: Text(
                          '"${state.transcript}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    const SizedBox(height: 30),

                    // Glowing Orb
                    Center(
                      child: VoiceOrb(
                        state: state.orbState,
                        onTap: () {
                          ref.read(assistantControllerProvider.notifier).toggleListening();
                        },
                        size: 140,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Dynamic State Banner
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStateColor(state.orbState).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          state.orbState.name.toUpperCase(),
                          style: TextStyle(
                            color: _getStateColor(state.orbState),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // AI Text Response Area
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.glassDecoration(isDark: isDark, opacity: 0.05),
                      child: Text(
                        state.responseText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Keyboard/Type accessibility bottom bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Type a command...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                      ),
                      onSubmitted: (_) => _sendManualText(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                    onPressed: _sendManualText,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStateColor(OrbState orbState) {
    switch (orbState) {
      case OrbState.listening:
        return AppTheme.error; // Red pulse
      case OrbState.processing:
        return AppTheme.primary; // Purple rotate
      case OrbState.responding:
        return AppTheme.success; // Green pulse
      case OrbState.error:
        return AppTheme.warning;
      case OrbState.idle:
      return AppTheme.accent; // Cyan glow
    }
  }
}
