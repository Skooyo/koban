import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import '../device/device_control.dart';
import 'user_error.dart';

/// The QR picture at [path] as the person page shows it: at most 1024 px on its long side,
/// like 0.1.1. A small picture is not made bigger. This is also its key in the image cache.
ResizeImage qrImage(String path) => ResizeImage(
  FileImage(File(path)),
  width: 1024,
  height: 1024,
  policy: ResizeImagePolicy.fit,
);

/// The picker copies each picture into the app cache. Delete that copy, and never a file outside the cache.
Future<void> deleteCachedPick(Directory cache, String path) async {
  if (!p.isWithin(cache.path, path)) return;
  final file = File(path);
  if (file.existsSync()) await file.delete();
  await qrImage(path).evict();
}

/// Payment QR pictures in app storage, and copies of them in the gallery.
/// A port of `QrStore.kt`. The picture of a person is `qr/<personId>.img`.
class QrStore {
  QrStore({required this._filesDir, required this._device});

  final Future<Directory> Function() _filesDir;
  final DeviceControl _device;

  /// Copies the picture at [sourcePath] to `qr/<personId>.img` and returns the absolute path.
  /// A file that is not a picture gives a [KobanUserError] and the old QR stays.
  Future<String> importQr(String personId, String sourcePath) async {
    final source = File(sourcePath);
    try {
      final codec = await ui.instantiateImageCodec(await source.readAsBytes());
      codec.dispose();
    } on Exception {
      throw const KobanUserError("That file isn't an image.");
    }
    final dir = Directory(p.join((await _filesDir()).path, 'qr'));
    await dir.create(recursive: true);
    final target = File(p.join(dir.path, '$personId.img'));
    // Copy to a temp file first so a failed copy keeps the old QR.
    final temp = File(p.join(dir.path, '$personId.tmp'));
    try {
      await source.copy(temp.path);
      try {
        await temp.rename(target.path);
      } on FileSystemException {
        await temp.copy(target.path);
      }
    } finally {
      if (await temp.exists()) await temp.delete();
    }
    // The day the QR was added: a copy may keep the date of the picked file.
    await target.setLastModified(DateTime.now());
    // The picture of this path changed: the next paint must read the new file.
    final path = target.absolute.path;
    await qrImage(path).evict();
    return path;
  }

  /// Deletes the file at [path]. A null or missing path does nothing.
  Future<void> delete(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
    await qrImage(path).evict();
  }

  /// The bytes of the file at [path], or null when there is none. Undo of a delete writes them back.
  Future<Uint8List?> read(String? path) async {
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file.readAsBytes() : null;
  }

  /// The day the picture at [path] was added, or null when there is no file.
  Future<DateTime?> addedAt(String? path) async {
    if (path == null) return null;
    final file = File(path);
    return await file.exists() ? file.lastModified() : null;
  }

  /// The side file that keeps the old picture while Undo is possible.
  String _oldPath(String path) => '${p.withoutExtension(path)}.old';

  /// Copies the picture at [path] to its side file, with the same day. False when there is none.
  Future<bool> keepOld(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    // A side file that a dead app left behind: copy does not replace it on Windows.
    await dropOld(path);
    final kept = await file.copy(_oldPath(path));
    await kept.setLastModified(await file.lastModified());
    return true;
  }

  /// Puts the side file back as the picture at [path], and deletes the side file.
  Future<void> restoreOld(String path) async {
    final kept = File(_oldPath(path));
    if (!await kept.exists()) return;
    // Write in place: a picture that the page still reads cannot be replaced by a rename on
    // Windows. The side file stays until the write is done, so a crash loses nothing.
    final bytes = await kept.readAsBytes();
    final day = await kept.lastModified();
    final target = File(path);
    await target.writeAsBytes(bytes);
    await target.setLastModified(day);
    await kept.delete();
    await qrImage(path).evict();
  }

  /// Deletes the side file. Nothing happens when there is none.
  Future<void> dropOld(String path) async {
    final kept = File(_oldPath(path));
    if (await kept.exists()) await kept.delete();
  }

  /// Writes [bytes] to [path] over any file there, and sets the day it was added. Undo uses it.
  Future<void> put(String path, Uint8List bytes, DateTime? addedAt) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    if (addedAt != null) await file.setLastModified(addedAt);
    await qrImage(path).evict();
  }

  /// Writes [bytes] back to [path]. A file that is already there stays.
  Future<void> restore(String path, Uint8List bytes) async {
    final file = File(path);
    if (await file.exists()) return;
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    await qrImage(path).evict();
  }

  /// Saves the QR at [path] to Pictures/Koban as [displayName].
  Future<void> saveToGallery(String path, String displayName) =>
      _device.saveImageToGallery(path, displayName);
}
