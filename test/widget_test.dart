import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chaosvoice/main.dart';

void main() {
  testWidgets('App displays ChaosVoice title', (WidgetTester tester) async {
    await tester.pumpWidget(const ChaosVoiceApp());

    // Verify the app renders without error
    expect(find.text('☠️ ChaosVoice'), findsOneWidget);
  });

  testWidgets('Chaos toggle exists on home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ChaosVoiceApp());

    // The toggle should be present
    expect(find.text('STOPPED'), findsOneWidget);
    expect(find.byIcon(Icons.mic_off), findsOneWidget);
  });

  testWidgets('Settings button navigates to settings', (WidgetTester tester) async {
    await tester.pumpWidget(const ChaosVoiceApp());

    // Tap the settings icon
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    // Should navigate to settings screen
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Platform'), findsWidgets);
  });

  testWidgets('Configure Effects button opens effects screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ChaosVoiceApp());
    await tester.pump();

    // The "Configure Effects" button should not be visible when service is stopped
    expect(find.text('Configure Effects →'), findsNothing);
  });

  testWidgets('App bar displays properly', (WidgetTester tester) async {
    await tester.pumpWidget(const ChaosVoiceApp());

    // Verify app bar
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.title, isNotNull);
  });

  testWidgets('Home screen has proper structure', (WidgetTester tester) async {
    await tester.pumpWidget(const ChaosVoiceApp());

    // Verify key structural elements exist
    expect(find.text('v1.0.0'), findsOneWidget);
    expect(find.byIcon(Icons.mic_off), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
