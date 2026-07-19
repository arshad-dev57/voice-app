import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../routing/app_router.dart';

class OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;
  final Gradient gradient;

  OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: 'Hands-Free Control',
      description: 'Interact with your smartphone using natural voice commands. Shake to trigger or wake by voice.',
      icon: Icons.waves_rounded,
      gradient: AppTheme.primaryGradient,
    ),
    OnboardingSlide(
      title: 'Voice Calls & SMS',
      description: 'Make hands-free calls and send messages effortlessly to contacts in English, Urdu, or Roman Urdu.',
      icon: Icons.phone_forwarded_rounded,
      gradient: AppTheme.respondingGradient,
    ),
    OnboardingSlide(
      title: 'Alarms & Reminders',
      description: 'Set offline reminders, alarms, and manage calendar schedules with direct voice-to-text alerts.',
      icon: Icons.add_alarm_rounded,
      gradient: AppTheme.processingGradient,
    ),
    OnboardingSlide(
      title: 'Multilingual AI Assistant',
      description: 'Seamlessly type, translate, and speak in Urdu, Roman Urdu, English, or mixed-language phrases.',
      icon: Icons.translate_rounded,
      gradient: AppTheme.primaryGradient,
    ),
    OnboardingSlide(
      title: 'Privacy & Offline Mode',
      description: 'Your voice recordings and sensitive contact data remain stored locally and securely on your device.',
      icon: Icons.security_rounded,
      gradient: AppTheme.respondingGradient,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Slides
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                        ? [AppTheme.darkBg, const Color(0xFF151922)] 
                        : [AppTheme.lightBg, const Color(0xFFE5ECF4)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glowing Icon Container
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: slide.gradient,
                        boxShadow: [
                          BoxShadow(
                            color: slide.gradient.colors.first.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        slide.icon,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 50),
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      slide.description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: isDark ? AppTheme.darkText : AppTheme.lightText,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Skipping and Dot indicators
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Skip Button
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRouter.languageSelect);
                  },
                  child: Text(
                    'SKIP',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                
                // Dots
                Row(
                  children: List.generate(
                    _slides.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      height: 8,
                      width: _currentIndex == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index 
                            ? AppTheme.primary 
                            : (isDark ? Colors.white24 : Colors.black12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                
                // Next / Let's Go Button
                ElevatedButton(
                  onPressed: () {
                    if (_currentIndex == _slides.length - 1) {
                      Navigator.pushReplacementNamed(context, AppRouter.languageSelect);
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    _currentIndex == _slides.length - 1 ? 'START' : 'NEXT',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
