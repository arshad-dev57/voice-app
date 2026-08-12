import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/shake_detection_service.dart';
import '../../../../routing/app_router.dart';
import '../../../../shared/widgets/voice_orb.dart';
import '../../../../theme/app_theme.dart';
import '../controllers/assistant_controller.dart';

/// Single-flow home for visually impaired users.
///
/// Shake the phone or tap anywhere on the screen. The assistant asks what
/// to do, then places calls, sends SMS, or sets alarms via Android.
class VoiceAssistantScreen extends ConsumerStatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  ConsumerState<VoiceAssistantScreen> createState() =>
      _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends ConsumerState<VoiceAssistantScreen>
    with WidgetsBindingObserver {
  String _lastAnnounced = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final text = ref.read(assistantControllerProvider).responseText;
      _announce(text);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ShakeDetectionService.startDetection();
    }
  }

  void _announce(String text) {
    if (text.isEmpty || text == _lastAnnounced) return;
    _lastAnnounced = text;
    SemanticsService.announce(text, TextDirection.ltr);
  }

  String _statusLabel(OrbState state) {
    switch (state) {
      case OrbState.listening:
        return 'Listening. Speak now.';
      case OrbState.processing:
        return 'Processing your request.';
      case OrbState.responding:
        return 'Assistant is speaking.';
      case OrbState.error:
        return 'Something went wrong.';
      case OrbState.idle:
        return 'Ready. Shake the phone or double tap the screen to talk.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen(assistantControllerProvider, (previous, next) {
      if (next.responseText.isNotEmpty &&
          next.responseText != previous?.responseText) {
        _announce(next.responseText);
      }
      if (next.navigationTarget != null) {
        final target = next.navigationTarget!;
        ref.read(assistantControllerProvider.notifier).clearNavigation();
        Navigator.pushNamed(context, target);
      }
    });

    return Scaffold(
      body: Semantics(
        label: '${_statusLabel(state.orbState)} ${state.responseText}',
        button: true,
        hint: 'Double tap to talk. Shake the phone from anywhere.',
        onTap: () {
          ref.read(assistantControllerProvider.notifier).startVoiceSession();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            ref.read(assistantControllerProvider.notifier).startVoiceSession();
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
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
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: 'Settings',
                          child: IconButton(
                            icon: const Icon(Icons.settings_rounded),
                            tooltip: 'Settings',
                            onPressed: () {
                              Navigator.pushNamed(context, AppRouter.settings);
                            },
                          ),
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: 'Activity history',
                          child: IconButton(
                            icon: const Icon(Icons.history_rounded),
                            tooltip: 'History',
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                AppRouter.activityHistory,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ExcludeSemantics(
                            child: VoiceOrb(
                              state: state.orbState,
                              onTap: () {
                                ref
                                    .read(assistantControllerProvider.notifier)
                                    .startVoiceSession();
                              },
                              size: 180,
                            ),
                          ),
                          const SizedBox(height: 28),
                          ExcludeSemantics(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _stateColor(state.orbState)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                _statusLabel(state.orbState),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _stateColor(state.orbState),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          ExcludeSemantics(
                            child: Text(
                              state.responseText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          if (state.transcript.isNotEmpty &&
                              state.orbState == OrbState.listening) ...[
                            const SizedBox(height: 20),
                            ExcludeSemantics(
                              child: Text(
                                '"${state.transcript}"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                      child: Text(
                        'Shake your phone or tap the screen.\nCall, message, or set an alarm.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _stateColor(OrbState orbState) {
    switch (orbState) {
      case OrbState.listening:
        return AppTheme.error;
      case OrbState.processing:
        return AppTheme.primary;
      case OrbState.responding:
        return AppTheme.success;
      case OrbState.error:
        return AppTheme.warning;
      case OrbState.idle:
        return AppTheme.accent;
    }
  }
}
