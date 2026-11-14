import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koban/receipts/receipt_photos.dart';
import 'package:path/path.dart' as p;

final tmp = Directory.systemTemp.path;

void main() {
  final cache = p.join(tmp, 'cachetest');

  test(
    'a file inside the cache is ours',
    () => expect(isCacheFile(p.join(cache, 'mlkit', 'scan.jpg'), cache), true),
  );
  test(
    'a content address is never ours',
    () => expect(
      isCacheFile(p.join(cache, 'content://media/external/images/1'), cache),
      false,
    ),
  );
  test(
    'a file outside the cache is not ours',
    () => expect(isCacheFile(p.join(tmp, 'other', 'scan.jpg'), cache), false),
  );
  test(
    'a path that climbs out with .. is not ours',
    () => expect(
      isCacheFile(p.join(cache, '..', 'other', 'scan.jpg'), cache),
      false,
    ),
  );
  test(
    'the cache folder itself is not ours',
    () => expect(isCacheFile(cache, cache), false),
  );
}
