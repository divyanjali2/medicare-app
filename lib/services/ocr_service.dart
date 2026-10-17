import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service to perform on-device OCR on photographed medicine labels/cards
/// using Google ML Kit (Latin script).
///
/// Scope: Extracts candidate medicine names only. Dosage, frequency, and
/// instructions are always entered manually for safety (see docs/decisions.md).
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static const List<String> _knownDrugs = [
    'Metformin',
    'Amlodipine',
    'Lisinopril',
    'Atorvastatin',
    'Paracetamol',
    'Losartan',
    'Aspirin',
    'Omeprazole',
    'Insulin',
  ];

  /// Pure function that extracts candidate medicine names from a list of OCR lines.
  ///
  /// Rules:
  /// - Lines of 2 characters or fewer are ignored.
  /// - Known drugs from [_knownDrugs] that appear anywhere in the lines (case-insensitive)
  ///   are placed first.
  /// - Followed by the first 4 raw lines as fallback suggestions.
  /// - No duplicates are allowed.
  /// - Empty input returns an empty list.
  static List<String> extractCandidates(List<String> rawLines) {
    final validLines = rawLines
        .map((l) => l.trim())
        .where((l) => l.length > 2)
        .toList();

    if (validLines.isEmpty) return [];

    final candidates = <String>[];

    // 1. First, check for any known drugs (case-insensitive) appearing in any line
    for (final drug in _knownDrugs) {
      final matches = validLines.any(
        (line) => line.toLowerCase().contains(drug.toLowerCase()),
      );
      if (matches && !candidates.any((c) => c.toLowerCase() == drug.toLowerCase())) {
        candidates.add(drug);
      }
    }

    // 2. Then, add the first 4 raw lines as fallback suggestions, with no duplicates
    for (final line in validLines.take(4)) {
      if (!candidates.any((c) => c.toLowerCase() == line.toLowerCase())) {
        candidates.add(line);
      }
    }

    return candidates;
  }

  /// Scans the given image file and returns a list of candidate medicine names.
  /// Gracefully catches platform channel errors (e.g. MissingPluginException on Web or
  /// desktop) and returns an empty list without crashing.
  Future<List<String>> scanName(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final result = await _recognizer.processImage(inputImage);
      final lines = result.text.split('\n');
      return extractCandidates(lines);
    } catch (e) {
      return [];
    }
  }

  Future<void> dispose() async {
    try {
      await _recognizer.close();
    } catch (_) {
      // Ignored: On web/unsupported platforms closing recognizer can throw MissingPluginException
    }
  }
}
