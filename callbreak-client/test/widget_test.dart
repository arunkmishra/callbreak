// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:callbreak_client/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CallbreakApp());

    // Verify that the home screen is displayed.
    expect(find.text('CALLBREAK'), findsOneWidget);
  });
}
