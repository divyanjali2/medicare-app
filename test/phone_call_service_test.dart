import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_app/services/phone_call_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhoneCallService Unit Tests', () {
    test('isValidPhoneNumber correctly identifies valid phone numbers', () {
      final service = PhoneCallService.instance;

      expect(service.isValidPhoneNumber('+94 77 123 4567'), isTrue);
      expect(service.isValidPhoneNumber('0771234567'), isTrue);
      expect(service.isValidPhoneNumber('+1 555-123-4567'), isTrue);
      expect(service.isValidPhoneNumber('0112345678'), isTrue);
    });

    test('isValidPhoneNumber rejects null, empty, and short numbers', () {
      final service = PhoneCallService.instance;

      expect(service.isValidPhoneNumber(null), isFalse);
      expect(service.isValidPhoneNumber(''), isFalse);
      expect(service.isValidPhoneNumber('   '), isFalse);
      expect(service.isValidPhoneNumber('123'), isFalse);
      expect(service.isValidPhoneNumber('call-me'), isFalse);
    });

    testWidgets('makePhoneCall invokes native MethodChannel with cleaned number', (tester) async {
      String? invokedMethod;
      dynamic invokedArguments;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.example.medicare_app/phone_call'),
        (MethodCall call) async {
          invokedMethod = call.method;
          invokedArguments = call.arguments;
          return true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PhoneCallService.instance.makePhoneCall(
                    context: context,
                    phoneNumber: '+94 77 123 4567',
                    recipientName: 'Amma',
                  );
                },
                child: const Text('Call'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();

      expect(invokedMethod, equals('makePhoneCall'));
      expect(invokedArguments, equals({'phoneNumber': '+94771234567'}));
      expect(find.textContaining('Opening dialer for Amma (+94771234567)...'), findsOneWidget);
    });

    testWidgets('makePhoneCall shows error SnackBar for invalid phone number without calling channel', (tester) async {
      bool channelInvoked = false;

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.example.medicare_app/phone_call'),
        (MethodCall call) async {
          channelInvoked = true;
          return true;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  PhoneCallService.instance.makePhoneCall(
                    context: context,
                    phoneNumber: '',
                    recipientName: 'Thaatha',
                  );
                },
                child: const Text('Call'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Call'));
      await tester.pumpAndSettle();

      expect(channelInvoked, isFalse);
      expect(find.text('No phone number registered for Thaatha.'), findsOneWidget);
    });
  });
}
