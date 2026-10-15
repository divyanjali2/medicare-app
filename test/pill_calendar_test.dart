import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_app/models/medicine.dart';
import 'package:medicare_app/widgets/pill_calendar.dart';

void main() {
  group('summarizeDay unit tests', () {
    DoseLog createLog(DoseStatus status) {
      return DoseLog(
        id: 'log-${DateTime.now().microsecondsSinceEpoch}',
        medicineId: 'med-1',
        scheduledFor: DateTime(2026, 9, 1, 8, 0),
        status: status,
      );
    }

    test('rule 1: empty list returns null', () {
      expect(summarizeDay([]), isNull);
    });

    test('rule 2: any missed returns missed (single missed)', () {
      final logs = [createLog(DoseStatus.missed)];
      expect(summarizeDay(logs), equals(DoseStatus.missed));
    });

    test('rule 2: any missed returns missed (mixed with taken and late)', () {
      final logs = [
        createLog(DoseStatus.taken),
        createLog(DoseStatus.late),
        createLog(DoseStatus.missed),
      ];
      expect(summarizeDay(logs), equals(DoseStatus.missed));
    });

    test('rule 2: any missed returns missed (mixed with pending)', () {
      final logs = [
        createLog(DoseStatus.pending),
        createLog(DoseStatus.missed),
      ];
      expect(summarizeDay(logs), equals(DoseStatus.missed));
    });

    test('rule 3: any late returns late when none missed (single late)', () {
      final logs = [createLog(DoseStatus.late)];
      expect(summarizeDay(logs), equals(DoseStatus.late));
    });

    test('rule 3: any late returns late when none missed (mixed with taken)', () {
      final logs = [
        createLog(DoseStatus.taken),
        createLog(DoseStatus.late),
      ];
      expect(summarizeDay(logs), equals(DoseStatus.late));
    });

    test('rule 3: any late returns late when none missed (mixed with pending)', () {
      final logs = [
        createLog(DoseStatus.pending),
        createLog(DoseStatus.late),
      ];
      expect(summarizeDay(logs), equals(DoseStatus.late));
    });

    test('rule 4: all taken returns taken (single taken)', () {
      final logs = [createLog(DoseStatus.taken)];
      expect(summarizeDay(logs), equals(DoseStatus.taken));
    });

    test('rule 4: all taken returns taken (multiple taken)', () {
      final logs = [
        createLog(DoseStatus.taken),
        createLog(DoseStatus.taken),
        createLog(DoseStatus.taken),
      ];
      expect(summarizeDay(logs), equals(DoseStatus.taken));
    });

    test('rule 5: otherwise returns pending (all pending)', () {
      final logs = [createLog(DoseStatus.pending)];
      expect(summarizeDay(logs), equals(DoseStatus.pending));
    });

    test('rule 5: otherwise returns pending (combination of taken and pending)', () {
      final logs = [
        createLog(DoseStatus.taken),
        createLog(DoseStatus.pending),
      ];
      expect(summarizeDay(logs), equals(DoseStatus.pending));
    });
  });

  group('PillCalendar widget tests', () {
    Widget buildTestHarness(Widget child) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: child,
          ),
        ),
      );
    }

    testWidgets('tapping a day fires onDayTap with the right date',
        (WidgetTester tester) async {
      DateTime? tappedDate;

      await tester.pumpWidget(
        buildTestHarness(
          PillCalendar(
            month: DateTime(2026, 9),
            statusByDay: {
              DateTime(2026, 9, 22): DoseStatus.taken,
            },
            selectedDay: null,
            onDayTap: (date) {
              tappedDate = date;
            },
            onMonthChange: (_) {},
          ),
        ),
      );

      // Verify September 2026 is displayed
      expect(find.text('September 2026'), findsOneWidget);

      // Tap on day 22
      final day22 = find.text('22');
      expect(day22, findsOneWidget);
      await tester.tap(day22);
      await tester.pumpAndSettle();

      expect(tappedDate, equals(DateTime(2026, 9, 22)));
    });

    testWidgets('chevrons fire onMonthChange with previous and next month',
        (WidgetTester tester) async {
      DateTime? changedMonth;

      await tester.pumpWidget(
        buildTestHarness(
          PillCalendar(
            month: DateTime(2026, 9),
            statusByDay: const {},
            onDayTap: (_) {},
            onMonthChange: (month) {
              changedMonth = month;
            },
          ),
        ),
      );

      // Tap previous chevron
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(changedMonth, equals(DateTime(2026, 8)));

      // Tap next chevron
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(changedMonth, equals(DateTime(2026, 10)));
    });

    testWidgets('navigating across December/January rolls the year correctly',
        (WidgetTester tester) async {
      DateTime? changedMonth;

      // Starting in January 2026 -> previous should be December 2025
      await tester.pumpWidget(
        buildTestHarness(
          PillCalendar(
            month: DateTime(2026, 1),
            statusByDay: const {},
            onDayTap: (_) {},
            onMonthChange: (month) {
              changedMonth = month;
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      expect(changedMonth, equals(DateTime(2025, 12)));

      // Starting in December 2026 -> next should be January 2027
      await tester.pumpWidget(
        buildTestHarness(
          PillCalendar(
            month: DateTime(2026, 12),
            statusByDay: const {},
            onDayTap: (_) {},
            onMonthChange: (month) {
              changedMonth = month;
            },
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      expect(changedMonth, equals(DateTime(2027, 1)));
    });

    testWidgets('empty statusByDay renders safely without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          PillCalendar(
            month: DateTime(2026, 2), // 28 days
            statusByDay: const {},
            onDayTap: (_) {},
            onMonthChange: (_) {},
          ),
        ),
      );

      expect(find.text('February 2026'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(find.text('29'), findsNothing);
    });

    testWidgets('accessibility Semantics labels are correctly assigned',
        (WidgetTester tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(
        buildTestHarness(
          PillCalendar(
            month: DateTime(2026, 9),
            statusByDay: {
              DateTime(2026, 9, 1): DoseStatus.taken,
              DateTime(2026, 9, 5): DoseStatus.late,
              DateTime(2026, 9, 7): DoseStatus.missed,
              DateTime(2026, 9, 10): DoseStatus.pending,
            },
            onDayTap: (_) {},
            onMonthChange: (_) {},
          ),
        ),
      );

      // Verify semantics nodes exist with the expected labels
      expect(
        find.bySemanticsLabel('1, taken'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('5, late'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('7, missed'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('10, pending'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('22, no doses'),
        findsOneWidget,
      );

      semanticsHandle.dispose();
    });

    testWidgets('legend displays Taken, Late, and Missed labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          PillCalendar(
            month: DateTime(2026, 9),
            statusByDay: const {},
            onDayTap: (_) {},
            onMonthChange: (_) {},
          ),
        ),
      );

      expect(find.text('Taken'), findsOneWidget);
      expect(find.text('Late'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
    });
  });
}
