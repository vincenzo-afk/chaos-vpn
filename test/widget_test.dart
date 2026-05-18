import 'package:flutter_test/flutter_test.dart';
import 'package:chaosvoice/main.dart';

void main() {
  testWidgets('App displays ChaosVoice title', (WidgetTester tester) async {
    await tester.pumpWidget(const ChaosVoiceApp());

    // Verify the app renders without error
    expect(find.text('☠️ ChaosVoice'), findsOneWidget);
  });
}
