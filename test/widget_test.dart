import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tatvik/screens/auth/login_screen.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('Ready to grow?'), findsOneWidget);
    expect(find.text('CONTINUE WITH GITHUB'), findsOneWidget);
  });
}
