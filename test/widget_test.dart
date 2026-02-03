// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:echoreverse_flutter/main.dart';

void main() {
  testWidgets('EchoReverse app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EchoReverseApp());

    // Verify the app renders
    expect(find.text('ECHO'), findsOneWidget);
    expect(find.text('REVERSE'), findsOneWidget);
    expect(find.text('TAP TO RECORD'), findsOneWidget);
  });
}
