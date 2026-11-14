import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:koban/update/release_parser.dart';

String release(String tag, List<String> assets, {String? body = 'Fixes'}) =>
    jsonEncode({
      'tag_name': tag,
      'body': body,
      'assets': [
        for (final a in assets)
          {
            'name': a,
            'browser_download_url': 'https://example.test/$a',
            'size': 65000000,
          },
      ],
    });

void main() {
  test('a newer APK gives the update', () {
    expect(
      ReleaseParser.parseLatest(release('v0.7.0', ['koban-7.apk']), 6),
      const AvailableUpdate(
        versionCode: 7,
        versionName: '0.7.0',
        apkUrl: 'https://example.test/koban-7.apk',
        apkSize: 65000000,
        notes: 'Fixes',
      ),
    );
  });

  test('the same version gives nothing', () {
    expect(
      ReleaseParser.parseLatest(release('v0.7.0', ['koban-7.apk']), 7),
      isNull,
    );
  });

  test('a release with no APK asset gives nothing', () {
    expect(
      ReleaseParser.parseLatest(release('v0.7.0', ['notes.txt']), 6),
      isNull,
    );
  });

  test('bad JSON gives nothing', () {
    expect(ReleaseParser.parseLatest('{not json', 6), isNull);
  });

  test('of two APKs the highest number wins', () {
    expect(
      ReleaseParser.parseLatest(
        release('v0.8.0', ['koban-7.apk', 'koban-8.apk']),
        6,
      )?.versionCode,
      8,
    );
  });

  test('a null body gives empty notes', () {
    expect(
      ReleaseParser.parseLatest(
        release('v0.7.0', ['koban-7.apk'], body: null),
        6,
      )?.notes,
      '',
    );
  });

  test('an APK number above the 32-bit limit is skipped', () {
    expect(
      ReleaseParser.parseLatest(
        release('v9.9.9', ['koban-99999999999.apk']),
        6,
      ),
      isNull,
    );
  });

  test('a too large APK number does not hide a valid APK', () {
    expect(
      ReleaseParser.parseLatest(
        release('v0.7.0', ['koban-99999999999.apk', 'koban-7.apk']),
        6,
      )?.versionCode,
      7,
    );
  });
}
