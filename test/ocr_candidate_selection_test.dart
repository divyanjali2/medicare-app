import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_app/services/ocr_service.dart';

void main() {
  group('OCR Name Candidate Selection Logic', () {
    test('known drug is placed first in candidates (case-insensitive)', () {
      final lines = [
        'Central Pharmacy Colombo',
        'Take with meals twice a day',
        'metformin hydrochloride 500mg',
        'Refills: 2',
      ];

      final candidates = OcrService.extractCandidates(lines);

      expect(candidates.isNotEmpty, isTrue);
      expect(candidates.first, equals('Metformin'));
      expect(candidates.contains('Central Pharmacy Colombo'), isTrue);
    });

    test('duplicates are removed from candidate suggestions', () {
      final lines = [
        'Paracetamol 500mg',
        'paracetamol 500mg',
        'PARACETAMOL',
        'Paracetamol',
      ];

      final candidates = OcrService.extractCandidates(lines);

      // Should contain 'Paracetamol' exactly once
      final paracetamolCount = candidates
          .where((c) => c.toLowerCase() == 'paracetamol')
          .length;
      expect(paracetamolCount, equals(1));
    });

    test('short lines with 2 characters or fewer are ignored', () {
      final lines = [
        'A',
        'Rx',
        '12',
        '  ',
        'Atorvastatin 20mg',
        'No',
      ];

      final candidates = OcrService.extractCandidates(lines);

      expect(candidates.contains('A'), isFalse);
      expect(candidates.contains('Rx'), isFalse);
      expect(candidates.contains('12'), isFalse);
      expect(candidates.contains('No'), isFalse);
      expect(candidates.first, equals('Atorvastatin'));
    });

    test('empty input returns an empty list', () {
      expect(OcrService.extractCandidates([]), isEmpty);
      expect(OcrService.extractCandidates(['', '   ', 'a', '12']), isEmpty);
    });

    test('returns first 4 raw lines as fallback when no known drug matches', () {
      final lines = [
        'Line One Custom Medicine',
        'Line Two Dosage Info',
        'Line Three Instructions',
        'Line Four Clinic Name',
        'Line Five Extra Detail',
        'Line Six Overflow Detail',
      ];

      final candidates = OcrService.extractCandidates(lines);

      expect(candidates.length, equals(4));
      expect(candidates[0], equals('Line One Custom Medicine'));
      expect(candidates[1], equals('Line Two Dosage Info'));
      expect(candidates[2], equals('Line Three Instructions'));
      expect(candidates[3], equals('Line Four Clinic Name'));
      expect(candidates.contains('Line Five Extra Detail'), isFalse);
    });
  });
}
