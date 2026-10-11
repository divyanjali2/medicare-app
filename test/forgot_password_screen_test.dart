import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_app/l10n/app_localizations.dart';
import 'package:medicare_app/screens/forgot_password_screen.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('si'),
      ],
      home: child,
    );
  }

  testWidgets('ForgotPasswordScreen renders initial Phone step correctly',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const ForgotPasswordScreen(initialPhone: '0771234567'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('Send Verification Code'), findsOneWidget);
    expect(find.text('0771234567'), findsOneWidget);
  });

  testWidgets('ForgotPasswordScreen validates empty phone number',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        const ForgotPasswordScreen(initialPhone: ''),
      ),
    );
    await tester.pumpAndSettle();

    final sendButton = find.text('Send Verification Code');
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    expect(find.text('Please enter your phone number'), findsOneWidget);
  });
}
