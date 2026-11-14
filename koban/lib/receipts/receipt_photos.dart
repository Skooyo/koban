import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

/// Takes a photo of a receipt.
abstract interface class ReceiptPhotos {
  /// The path of the photo, or null when the user cancels.
  /// An error of the camera fallback (for example a camera permission
  /// [PlatformException]) goes to the caller.
  Future<String?> scan();
}

/// The document scanner of Google. Without it (no Play services), the phone camera.
class PhoneReceiptPhotos implements ReceiptPhotos {
  /// The message of the scanner plugin when the user closes the scanner.
  static const _cancelled = 'Operation cancelled';

  /// The message of the scanner plugin for a result that is not OK and not a cancel.
  /// 0.1.1 did nothing for it.
  static const _unknown = 'Unknown Error';

  @override
  Future<String?> scan() async {
    final scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormats: {DocumentFormat.jpeg},
        mode: ScannerMode.full,
        pageLimit: 1,
        isGalleryImport: false,
      ),
    );
    try {
      final result = await scanner.scanDocument();
      final images = result.images;
      return images == null || images.isEmpty ? null : images.first;
    } on PlatformException catch (e) {
      if (e.message == _cancelled || e.message == _unknown) return null;
      // No Play services or no activity: use the camera.
      return (await ImagePicker().pickImage(source: ImageSource.camera))?.path;
    } finally {
      await scanner.close();
    }
  }
}

/// True when [path] is a file inside [cacheDir]. The cache folder itself, a content
/// address and a path that climbs out of the cache are not.
bool isCacheFile(String path, String cacheDir) =>
    !path.contains('://') &&
    p.isWithin(p.canonicalize(cacheDir), p.canonicalize(path));

/// Deletes [path] only when it is a file inside [cacheDir]. A gallery file stays.
Future<void> deleteIfCache(String? path, String cacheDir) async {
  if (path == null || !isCacheFile(path, cacheDir)) return;
  final file = File(path);
  if (file.existsSync()) await file.delete();
}
