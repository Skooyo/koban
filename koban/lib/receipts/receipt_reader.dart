import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../rules/receipt_rules.dart';

/// Reads the text lines of a receipt photo.
abstract interface class ReceiptOcr {
  Future<List<OcrLine>> lines(String path);
}

/// Reads a photo on the phone with ML Kit. Port of the 0.1.1 `ReceiptReader`.
class MlKitReceiptOcr implements ReceiptOcr {
  @override
  Future<List<OcrLine>> lines(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text = await recognizer.processImage(InputImage.fromFilePath(path));
      return [
        for (final block in text.blocks)
          for (final line in block.lines)
            _ocrLine(line.text, line.boundingBox, line.angle ?? 0),
      ];
    } finally {
      await recognizer.close();
    }
  }

  static OcrLine _ocrLine(String text, Rect box, double angle) => OcrLine(
    text,
    box.left.round(),
    box.top.round(),
    box.right.round(),
    box.bottom.round(),
    angle: angle,
  );
}

/// Reads a receipt photo on the phone: OCR, then [ReceiptRules].
class ReceiptReader {
  ReceiptReader(this._ocr, {required this.now});

  final ReceiptOcr _ocr;

  /// The clock in epoch milliseconds. A receipt date after it is not used.
  final int Function() now;

  /// The read, or null when the photo cannot be read or the rules find nothing.
  Future<ReceiptRead?> read(String path) async {
    try {
      return ReceiptRules.read(await _ocr.lines(path), now: now());
    } catch (_) {
      return null;
    }
  }
}
