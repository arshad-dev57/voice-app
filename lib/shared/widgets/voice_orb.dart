import 'dart:math';
import 'package:flutter/material.dart';
import '../../features/assistant/presentation/controllers/assistant_controller.dart';
import '../../theme/app_theme.dart';

class VoiceOrb extends StatefulWidget {
  final OrbState state;
  final VoidCallback onTap;
  final double size;

  const VoiceOrb({
    super.key,
    required this.state,
    required this.onTap,
    this.size = 120,
  });

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Gradient _getGradient() {
    switch (widget.state) {
      case OrbState.listening:
        return AppTheme.recordingGradient;
      case OrbState.processing:
        return AppTheme.processingGradient;
      case OrbState.responding:
        return AppTheme.respondingGradient;
      case OrbState.error:
        return AppTheme.errorGradient;
      case OrbState.idle:
        return AppTheme.primaryGradient;
    }
  }

  IconData _getIcon() {
    switch (widget.state) {
      case OrbState.listening:
        return Icons.mic_rounded;
      case OrbState.processing:
        return Icons.psychology_rounded;
      case OrbState.responding:
        return Icons.volume_up_rounded;
      case OrbState.error:
        return Icons.error_outline_rounded;
      case OrbState.idle:
        return Icons.mic_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _getGradient();
    final icon = _getIcon();

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double pulse = 1.0;
          double rotation = 0.0;

          if (widget.state == OrbState.listening) {
            pulse = 1.0 + 0.15 * sin(_controller.value * 2 * pi);
          } else if (widget.state == OrbState.processing) {
            rotation = _controller.value * 2 * pi;
          } else if (widget.state == OrbState.responding) {
            pulse = 1.0 + 0.08 * sin(_controller.value * 4 * pi);
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glowing Rings
              if (widget.state == OrbState.listening || widget.state == OrbState.responding)
                ...List.generate(2, (index) {
                  final scale = pulse + (index * 0.15);
                  final opacity = (0.3 - (index * 0.1)).clamp(0.0, 1.0);
                  return Container(
                    width: widget.size * scale,
                    height: widget.size * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gradient.colors.first.withValues(alpha: opacity),
                    ),
                  );
                }),

              // Main Orb Container
              Transform.rotate(
                angle: rotation,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withValues(alpha: 0.5),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),

              // Centered Icon
              Icon(
                icon,
                size: widget.size * 0.4,
                color: Colors.white,
              ),
            ],
          );
        },
      ),
    );
  }
}
