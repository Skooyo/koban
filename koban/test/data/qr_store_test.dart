import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/people_repository.dart';
import 'package:koban/data/qr_store.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/data/user_error.dart';
import 'package:koban/device/device_control.dart';
import 'package:path/path.dart' as p;

import '../support/harness.dart';

/// A 1 x 1 PNG picture.
final pngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
  0x0d, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xff, 0xff, 0x3f,
  0x00, 0x05, 0xfe, 0x02, 0xfe, 0xa7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);

/// A valid 2 x 1 PNG picture, another size than [pngBytes].
final wideBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0xf4, 0x22, 0x7f, 0x8a, 0x00, 0x00, 0x00,
  0x0e, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x60, 0x60, 0x60, 0xf8,
  0x0f, 0xc2, 0x00, 0x06, 0x03, 0x01, 0xff, 0xcf, 0x87, 0xc6, 0x70, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);

/// Puts a picture that never loads in the image cache under the key of the QR at [path].
Future<Object> cacheQr(String path) async {
  final key = await qrImage(path).obtainKey(ImageConfiguration.empty);
  imageCache.putIfAbsent(
    key,
    () => OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
  );
  expect(imageCache.containsKey(key), isTrue);
  return key;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KobanDatabase db;
  late Directory files;
  late PeopleRepository repo;
  late FakeChannel channel;

  setUp(() {
    db = KobanDatabase(NativeDatabase.memory());
    files = Directory.systemTemp.createTempSync('koban_qr');
    channel = FakeChannel(deviceChannelName, {
      'saveImageToGallery': 'content://x',
    });
    repo = PeopleRepository(
      db,
      splits: SplitRepository(db, now: () => 1),
      qr: QrStore(filesDir: () async => files, device: DeviceControl()),
      now: () => 1,
    );
  });
  tearDown(() async {
    await db.close();
    files.deleteSync(recursive: true);
  });

  Future<SplitPeopleData> row(String id) =>
      (db.select(db.splitPeople)..where((p) => p.id.equals(id))).getSingle();

  File source(String name, List<int> bytes) =>
      File('${files.path}/$name')..writeAsBytesSync(bytes);

  test(
    'a QR import copies the picture to qr/<id>.img and the person points at it',
    () async {
      final ali = await repo.addPerson('Ali');
      final picked = source('picked.png', pngBytes);

      await repo.setQr(ali, picked.path);

      final target = File(p.join(files.path, 'qr', '$ali.img'));
      expect((await row(ali)).qrPath, target.absolute.path);
      expect(target.readAsBytesSync(), pngBytes);
      expect(File(p.join(files.path, 'qr', '$ali.tmp')).existsSync(), isFalse);
      expect(picked.existsSync(), isTrue);
    },
  );

  test('a new QR replaces the old picture at the same path', () async {
    final ali = await repo.addPerson('Ali');
    await repo.setQr(ali, source('a.png', pngBytes).path);
    final second = Uint8List.fromList([...pngBytes]);
    second[second.length - 5] = 0x43;
    await repo.setQr(ali, source('b.png', second).path);

    expect(
      File(p.join(files.path, 'qr', '$ali.img')).readAsBytesSync(),
      second,
    );
  });

  // Review Focus 1: the person page shows the new picture, not the cached old one.
  test('a QR import drops the cached picture of the page', () async {
    final ali = await repo.addPerson('Ali');
    final target = File(p.join(files.path, 'qr', '$ali.img')).absolute.path;
    await repo.setQr(ali, source('a.png', pngBytes).path);
    final key = await cacheQr(target);

    await repo.setQr(ali, source('b.png', wideBytes).path);

    expect((await row(ali)).qrPath, target);
    expect(imageCache.containsKey(key), isFalse);
  });

  test('the page shows the QR at most 1024 px on its long side', () {
    final image = qrImage('/x/qr/a.img');
    expect(image.width, 1024);
    expect(image.height, 1024);
    expect(image.policy, ResizeImagePolicy.fit);
    expect(image.allowUpscaling, isFalse);
    expect((image.imageProvider as FileImage).file.path, '/x/qr/a.img');
  });

  test('archive drops the cached picture of the QR', () async {
    final ali = await repo.addPerson('Ali');
    await repo.setQr(ali, source('a.png', pngBytes).path);
    final key = await cacheQr((await row(ali)).qrPath!);

    await repo.archivePerson(ali);

    expect(imageCache.containsKey(key), isFalse);
  });

  test('a file that is not a picture keeps the old QR', () async {
    final ali = await repo.addPerson('Ali');
    await repo.setQr(ali, source('good.png', pngBytes).path);
    final before = (await row(ali)).qrPath;

    Object? error;
    try {
      await repo.setQr(ali, source('note.txt', 'not a picture'.codeUnits).path);
    } on KobanUserError catch (e) {
      error = e;
    }

    expect((error! as KobanUserError).message, "That file isn't an image.");
    expect((await row(ali)).qrPath, before);
    expect(File(before!).readAsBytesSync(), pngBytes);
  });

  test('save to gallery uses a safe file name', () async {
    final ali = await repo.addPerson('Ali bin Abu');
    await repo.setQr(ali, source('picked.png', pngBytes).path);

    await repo.saveQrToGallery(ali);

    final call = channel.calls.single;
    expect(call.method, 'saveImageToGallery');
    expect(call.arguments, {
      'path': File(p.join(files.path, 'qr', '$ali.img')).absolute.path,
      'displayName': 'koban-Ali-bin-Abu-qr.jpg',
    });
  });
}
