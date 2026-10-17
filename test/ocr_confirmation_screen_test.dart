import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medicare_app/screens/add_manually_screen.dart';
import 'package:medicare_app/screens/add_medicine_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OCR Confirmation & Add Medicine Scan Flow', () {
    testWidgets('Scan screen renders "Scan medicine card" button and "Enter manually"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddMedicineScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Scan medicine card'), findsOneWidget);
      expect(find.text('Enter manually'), findsOneWidget);
    });

    testWidgets('Confirmation screen pre-fills candidate.first and sets dosage/freq/instructions empty', (tester) async {
      final candidates = ['Metformin', 'Metformin 500mg', 'Metformin Tablet'];

      await tester.pumpWidget(
        MaterialApp(
          home: AddManuallyScreen(
            isFromScan: true,
            candidates: candidates,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Name pre-filled with candidates.first
      expect(find.widgetWithText(TextFormField, 'Metformin'), findsOneWidget);

      // Remaining candidates shown as ChoiceChips
      expect(find.byType(ChoiceChip), findsNWidgets(2));
      expect(find.widgetWithText(ChoiceChip, 'Metformin 500mg'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Metformin Tablet'), findsOneWidget);

      // Tapping a ChoiceChip fills the name field
      await tester.tap(find.widgetWithText(ChoiceChip, 'Metformin 500mg'));
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Metformin 500mg'), findsOneWidget);

      // "Save medicine" button is DISABLED because dosage and frequency are empty
      final saveButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('Shows warning message and empty name when OCR returns no candidates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddManuallyScreen(
            isFromScan: true,
            candidates: [],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Warning message
      expect(find.text("Couldn't read the name, please type it"), findsOneWidget);

      // Name field is empty
      final nameField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, '').first,
      );
      expect(nameField.controller?.text, isEmpty);

      // Save button is disabled
      final saveButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('Enables "Save medicine" only when name, dosage, and frequency are non-empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddManuallyScreen(
            isFromScan: true,
            candidates: ['Amlodipine'],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially disabled (dosage & frequency empty)
      var saveButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(saveButton.onPressed, isNull);

      // Enter dosage
      final dosageFinder = find.widgetWithText(TextFormField, '');
      await tester.enterText(dosageFinder.first, '5 mg');
      await tester.pump();

      // Still disabled because frequency is empty
      saveButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(saveButton.onPressed, isNull);

      // Select frequency from dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Once daily').last);
      await tester.pumpAndSettle();

      // Now Save button is ENABLED
      saveButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(saveButton.onPressed, isNotNull);
    });
  });
}
