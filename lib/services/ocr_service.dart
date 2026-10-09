import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Scans a photographed, PRINTED medicine label and parses out likely
/// medicine fields.
///
/// Scope boundary (documented decision, see docs/decisions.md):
/// - OCR targets printed pharmacy labels / pill packets only, which are
///   reliably in English in the Sri Lankan context.
/// - Handwritten doctor prescriptions and Sinhala-script recognition are
///   explicitly OUT of scope — both are high-risk, low-accuracy problems
///   for an 8-week build. Users confirm/correct every scanned field before
///   it is saved (see AddMedicineFlow -> OcrConfirmationScreen).
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ParsedLabel> scanLabel(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final result = await _recognizer.processImage(inputImage);
    return _parse(result.text);
  }

  /// Very small rule-based parser over the raw OCR text. Looks for common
  /// dosage/frequency patterns. This is intentionally simple — the user
  /// always reviews and corrects the result on the confirmation screen,
  /// so parser mistakes are not safety-critical.
  ParsedLabel _parse(String rawText) {
    final dosageMatch = RegExp(r'(\d+(\.\d+)?\s?mg)', caseSensitive: false)
        .firstMatch(rawText);
    final freqMatch = RegExp(
      r'(once|twice|three times|1x|2x|3x)\s?(daily|a day)?',
      caseSensitive: false,
    ).firstMatch(rawText);

    final firstLine = rawText.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );

    return ParsedLabel(
      rawText: rawText,
      guessedName: firstLine.trim(),
      guessedDosage: dosageMatch?.group(0) ?? '',
      guessedFrequency: freqMatch?.group(0) ?? '',
    );
  }

  void dispose() => _recognizer.close();
}

class ParsedLabel {
  final String rawText;
  final String guessedName;
  final String guessedDosage;
  final String guessedFrequency;

  const ParsedLabel({
    required this.rawText,
    required this.guessedName,
    required this.guessedDosage,
    required this.guessedFrequency,
  });
}
