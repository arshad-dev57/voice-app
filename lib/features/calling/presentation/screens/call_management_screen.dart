import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../theme/app_theme.dart';

class CallManagementScreen extends StatefulWidget {
  final String contactName;
  final String phoneNumber;
  final bool incoming;

  const CallManagementScreen({
    super.key,
    required this.contactName,
    required this.phoneNumber,
    required this.incoming,
  });

  @override
  State<CallManagementScreen> createState() => _CallManagementScreenState();
}

class _CallManagementScreenState extends State<CallManagementScreen> {
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    if (!widget.incoming) {
      _startCallSimulation();
    }
  }

  void _startCallSimulation() {
    // Delay connecting by 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _secondsElapsed++;
            });
          }
        });
      }
    });

    // Trigger the native device dialer with the contact's number.
    // Using the `tel:` scheme opens the phone app so no CALL_PHONE
    // runtime permission is required (Play Store safe).
    if (widget.phoneNumber.isNotEmpty) {
      final Uri url = Uri(scheme: 'tel', path: widget.phoneNumber);
      canLaunchUrl(url).then((canLaunch) {
        if (canLaunch) {
          launchUrl(url);
        }
      });
    }
  }

  void _answerCall() {
    setState(() {
      _isConnected = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  void _endCall() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    final int min = seconds ~/ 60;
    final int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.contactName.isEmpty
        ? 'Unknown Caller'
        : widget.contactName;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.darkBg, const Color(0xFF1F2430)]
                : [AppTheme.lightBg, const Color(0xFFE2E9F3)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Contact details
              Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 48,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.phoneNumber,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    !_isConnected
                        ? (widget.incoming
                              ? 'Incoming Call...'
                              : 'Connecting...')
                        : 'Active Call: ${_formatDuration(_secondsElapsed)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: !_isConnected
                          ? AppTheme.primary
                          : AppTheme.success,
                    ),
                  ),
                ],
              ),

              // Action buttons during call
              if (_isConnected)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _callActionToggle(
                      icon: _isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      isActive: _isMuted,
                      onTap: () => setState(() => _isMuted = !_isMuted),
                    ),
                    const SizedBox(width: 30),
                    _callActionToggle(
                      icon: _isSpeakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      isActive: _isSpeakerOn,
                      onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                    ),
                  ],
                ),

              // End / Answer buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.incoming && !_isConnected) ...[
                    // Accept Call Button
                    FloatingActionButton(
                      heroTag: 'acceptCall',
                      onPressed: _answerCall,
                      backgroundColor: AppTheme.success,
                      child: const Icon(Icons.call, color: Colors.white),
                    ),
                    const SizedBox(width: 40),
                  ],
                  // Reject/End Call Button
                  FloatingActionButton(
                    heroTag: 'endCall',
                    onPressed: _endCall,
                    backgroundColor: AppTheme.error,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _callActionToggle({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive
              ? AppTheme.primary
              : Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : AppTheme.primary,
          size: 28,
        ),
      ),
    );
  }
}
