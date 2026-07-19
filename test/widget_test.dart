import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voice_recoginization_app/main.dart';

void main() {
  testWidgets('App launches and shows Splash Screen', (
    WidgetTester tester,
  ) async {
    // Build our app wrapped in ProviderScope
    await tester.pumpWidget(
      const ProviderScope(child: SmartVoiceAssistantApp()),
    );

    // Advance 600ms to allow the fade-in animation to progress past opacity 0
    await tester.pump(const Duration(milliseconds: 600));

    // The splash screen microphone icon should be visible
    expect(find.byIcon(Icons.mic_rounded), findsWidgets);
  });
}
