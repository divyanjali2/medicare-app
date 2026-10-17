import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medicare_app/models/medicine.dart';
import 'package:medicare_app/screens/add_manually_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testMedicine = Medicine(
    id: 'med-test-1',
    patientId: 'patient-test-1',
    name: 'Atorvastatin',
    dosage: '20 mg',
    frequency: 'Once daily',
    instructions: 'At bedtime with water',
    scheduledTimes: [DateTime(2026, 10, 16, 21, 0)],
    createdAt: DateTime(2026, 10, 16),
  );

  testWidgets('AddManuallyScreen pre-populates details when editing existing medicine', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddManuallyScreen(
          existingMedicine: testMedicine,
          patientId: 'patient-test-1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify fields contain existing medicine details
    expect(find.widgetWithText(TextFormField, 'Atorvastatin'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '20 mg'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'At bedtime with water'), findsOneWidget);

    // Verify screen title and action button reflect edit mode
    expect(find.text('EDIT MEDICINE'), findsOneWidget);
    expect(find.text('Edit medicine'), findsOneWidget);
    expect(find.text('Update medicine'), findsOneWidget);
  });

  testWidgets('AddManuallyScreen correctly sets time of day to Evening for 18:00', (tester) async {
    final eveningMed = Medicine(
      id: 'med-test-2',
      patientId: 'patient-test-1',
      name: 'Metformin',
      dosage: '500 mg',
      frequency: 'Twice daily',
      instructions: 'With dinner',
      scheduledTimes: [DateTime(2026, 10, 16, 18, 0)],
      createdAt: DateTime(2026, 10, 16),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddManuallyScreen(
          existingMedicine: eveningMed,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.widgetWithText(TextFormField, 'Metformin'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '500 mg'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'With dinner'), findsOneWidget);

    final state = tester.state<AddManuallyScreenState>(find.byType(AddManuallyScreen));
    expect(state.selectedTimesOfDay.contains('Evening'), isTrue);
  });

  testWidgets('AddManuallyScreen supports multiple times of day (Morning & Night, or All 3)', (tester) async {
    final multiMed = Medicine(
      id: 'med-test-3',
      patientId: 'patient-test-1',
      name: 'Metformin',
      dosage: '500 mg',
      frequency: 'Twice daily',
      instructions: 'Morning and Night',
      scheduledTimes: [
        DateTime(2026, 10, 16, 8, 0),
        DateTime(2026, 10, 16, 21, 0),
      ],
      createdAt: DateTime(2026, 10, 16),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AddManuallyScreen(
          existingMedicine: multiMed,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final state = tester.state<AddManuallyScreenState>(find.byType(AddManuallyScreen));
    expect(state.selectedTimesOfDay.contains('Morning'), isTrue);
    expect(state.selectedTimesOfDay.contains('Night'), isTrue);
    expect(state.selectedTimesOfDay.contains('Evening'), isFalse);

    // Scroll and tap "All 3" quick select
    await tester.ensureVisible(find.text('All 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All 3'));
    await tester.pump();

    expect(state.selectedTimesOfDay.length, equals(3));
    expect(state.selectedTimesOfDay.contains('Morning'), isTrue);
    expect(state.selectedTimesOfDay.contains('Evening'), isTrue);
    expect(state.selectedTimesOfDay.contains('Night'), isTrue);
  });
}
