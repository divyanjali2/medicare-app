import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_app/screens/patient_medicines_screen.dart';

void main() {
  testWidgets('PatientMedicinesScreen renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PatientMedicinesScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PatientMedicinesScreen), findsOneWidget);
  });
}
