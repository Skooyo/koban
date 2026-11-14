import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koban/data/settings_store.dart';
import 'package:koban/online/secret_store.dart';
import 'package:koban/update/release_parser.dart';
import 'package:koban/update/update_installer.dart';
import 'package:koban/update/update_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/harness.dart';

const t = 100000000;
const seven = AvailableUpdate(
  versionCode: 7,
  versionName: '0.7.0',
  apkUrl: 'https://example.test/koban-7.apk',
  apkSize: 5,
  notes: 'Fixes',
);

String release(String asset) => jsonEncode({
  'tag_name': 'v0.7.0',
  'body': 'Fixes',
  'assets': [
    {
      'name': asset,
      'browser_download_url': 'https://example.test/$asset',
      'size': 5,
    },
  ],
});

void main() {
  late FakeUpdateInstaller installer;
  late String cache;
  late List<http.BaseRequest> requests;
  late Future<http.StreamedResponse> Function(http.BaseRequest) answer;
  late KobanSettings settings;
  late UpdateRepository repo;

  http.StreamedResponse text(String body, [int status = 200]) =>
      http.StreamedResponse(Stream.value(utf8.encode(body)), status);

  Future<void> make({
    Map<String, Object> prefs = const {},
    Duration noData = const Duration(seconds: 60),
  }) async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData(prefs);
    settings = await KobanSettings.load(
      SharedPreferencesAsync(),
      secrets: SecretStore(SharedPreferencesAsync()),
    );
    repo = UpdateRepository(
      http: MockClient.streaming((request, _) {
        requests.add(request);
        return answer(request);
      }),
      settings: settings,
      installer: installer,
      cacheDir: () async => Directory(cache),
      now: () => DateTime.fromMillisecondsSinceEpoch(t),
      noDataLimit: noData,
    );
  }

  setUp(() {
    installer = FakeUpdateInstaller();
    requests = [];
    final dir = Directory.systemTemp.createTempSync('koban_cache');
    cache = dir.path.replaceAll('\\', '/');
    addTearDown(() => dir.deleteSync(recursive: true));
    answer = (r) async => r.url.host == 'api.github.com'
        ? text(release('koban-7.apk'))
        : text('12345');
  });

  Set<String> headerNames(http.BaseRequest r) =>
      r.headers.keys.map((k) => k.toLowerCase()).toSet();

  test('an automatic check finds the update and records the time', () async {
    await make();
    await repo.check(manual: false);
    expect(repo.state.value, const UpdateAvailable(seven));
    expect(await settings.lastUpdateCheck(), t);
    final r = requests.single;
    expect(headerNames(r), {'accept', 'user-agent'});
    expect(
      (r.headers['accept'], r.headers['user-agent']),
      ('application/vnd.github+json', 'Koban-Android'),
    );
  });

  test('a manual check with nothing new says up to date', () async {
    answer = (_) async => text(release('koban-6.apk'));
    await make();
    await repo.check(manual: true);
    expect(repo.state.value, const UpdateUpToDate());
  });

  test('an automatic check the same day sends nothing', () async {
    await make(prefs: {'last_update_check': t - 1000});
    await repo.check(manual: false);
    expect(requests, isEmpty);
    expect(repo.state.value, const UpdateIdle());
  });

  test(
    'a 403 is silent for the automatic check and shown for the manual one',
    () async {
      answer = (_) async => text('{}', 403);
      await make();
      await repo.check(manual: false);
      expect(repo.state.value, const UpdateIdle());
      expect(await settings.lastUpdateCheck(), t);
      await repo.check(manual: true);
      expect(
        repo.state.value,
        const UpdateFailed('Could not check for updates. Try again later.'),
      );
    },
  );

  test('with Online features off nothing is sent', () async {
    await make(prefs: {'online_features': false});
    await repo.check(manual: true);
    await repo.check(manual: false);
    expect(requests, isEmpty);
    expect(repo.state.value, const UpdateIdle());
  });

  test('Update downloads the APK, installs it and deletes the file', () async {
    await make();
    await repo.check(manual: false);
    await repo.downloadAndInstall();
    expect(installer.installs, [('$cache/updates/koban-7.apk', 7, 5)]);
    expect(File('$cache/updates/koban-7.apk').existsSync(), false);
    expect(repo.state.value, const UpdateInstalling());
    expect(requests.last.url.toString(), 'https://example.test/koban-7.apk');
    expect(headerNames(requests.last), {'user-agent'});
  });

  test('two fast taps start one download', () async {
    await make();
    await repo.check(manual: false);
    final first = repo.downloadAndInstall();
    final second = repo.downloadAndInstall();
    await Future.wait([first, second]);
    expect(requests.where((r) => r.url.host == 'example.test'), hasLength(1));
    expect(installer.installs, hasLength(1));
  });

  test('a download that ends early fails and never installs', () async {
    await make();
    await repo.check(manual: false);
    answer = (_) async =>
        http.StreamedResponse(Stream.value([1, 2, 3]), 200, contentLength: 5);
    await repo.downloadAndInstall();
    expect(
      repo.state.value,
      const UpdateFailed('Update failed. Try again later.', retry: seven),
    );
    expect(installer.installs, isEmpty);
    expect(File('$cache/updates/koban-7.apk').existsSync(), false);
  });

  test('a refused APK fails with the retry', () async {
    await make();
    await repo.check(manual: false);
    installer.installError = NotKobanApk();
    await repo.downloadAndInstall();
    expect(
      repo.state.value,
      const UpdateFailed('Update failed. Try again later.', retry: seven),
    );
    expect(File('$cache/updates/koban-7.apk').existsSync(), false);
  });

  test('without the install permission it opens the settings and asks to try again', () async {
    await make();
    await repo.check(manual: false);
    installer.allowed = false;
    await repo.downloadAndInstall();
    expect(installer.openedSettings, 1);
    expect(await settings.lastUpdateCheck(), 0);
    expect(
      repo.state.value,
      const UpdateFailed(
        'Allow Koban to install apps, then tap Update again.',
        retry: seven,
      ),
    );
    expect(requests.where((r) => r.url.host == 'example.test'), isEmpty);
    repo.later();
    expect(repo.state.value, const UpdateAvailable(seven));
  });

  test('Close while installing goes back to the update', () async {
    await make();
    await repo.check(manual: false);
    await repo.downloadAndInstall();
    repo.later();
    expect(repo.state.value, const UpdateAvailable(seven));
  });

  test('the install status moves the state', () async {
    await make();
    await repo.check(manual: false);
    await repo.downloadAndInstall();
    installer.emit(InstallStatus.pendingUserAction);
    expect(repo.state.value, const UpdateInstalling());
    installer.emit(InstallStatus.failure, 'x');
    expect(
      repo.state.value,
      const UpdateFailed('Update failed. Try again later.', retry: seven),
    );
    installer.emit(InstallStatus.success);
    expect(repo.state.value, const UpdateIdle());
  });

  test('no permission never shows the downloading state', () async {
    await make();
    await repo.check(manual: false);
    installer.allowed = false;
    final seen = <UpdateState>[];
    repo.state.addListener(() => seen.add(repo.state.value));
    final first = repo.downloadAndInstall();
    final second = repo.downloadAndInstall();
    await Future.wait([first, second]);
    expect(seen, [
      const UpdateFailed(
        'Allow Koban to install apps, then tap Update again.',
        retry: seven,
      ),
    ]);
    expect(installer.openedSettings, 1);
  });

  test('with Online features off Update sends nothing and goes idle', () async {
    await make();
    await repo.check(manual: false);
    await settings.setOnlineFeatures(false);
    await repo.downloadAndInstall();
    expect(repo.state.value, const UpdateIdle());
    expect(requests.where((r) => r.url.host == 'example.test'), isEmpty);
    expect(installer.installs, isEmpty);
  });

  test('a download that answers 404 fails with the retry', () async {
    await make();
    await repo.check(manual: false);
    answer = (_) async => text('gone', 404);
    await repo.downloadAndInstall();
    expect(
      repo.state.value,
      const UpdateFailed('Update failed. Try again later.', retry: seven),
    );
    expect(installer.installs, isEmpty);
  });

  test('an old file in the updates folder is removed first', () async {
    await make();
    await repo.check(manual: false);
    final old = File('$cache/updates/koban-5.apk')
      ..createSync(recursive: true)
      ..writeAsStringSync('old');
    await repo.downloadAndInstall();
    expect(old.existsSync(), false);
    expect(installer.installs, hasLength(1));
  });

  test('a response that never starts fails at the no-data limit and installs nothing', () async {
    await make(noData: const Duration(milliseconds: 50));
    await repo.check(manual: false);
    final never = Completer<http.StreamedResponse>();
    answer = (_) => never.future;
    await repo.downloadAndInstall();
    expect(
      repo.state.value,
      const UpdateFailed('Update failed. Try again later.', retry: seven),
    );
    expect(installer.installs, isEmpty);
    expect(File('$cache/updates/koban-7.apk').existsSync(), false);
  });

  test('Later during the permission check cancels the Update', () async {
    await make();
    await repo.check(manual: false);
    final gate = installer.canInstallGate = Completer<bool>();
    final tap = repo.downloadAndInstall();
    repo.later();
    gate.complete(true);
    await tap;
    expect(repo.state.value, const UpdateIdle());
    expect(requests.where((r) => r.url.host == 'example.test'), isEmpty);
    expect(installer.installs, isEmpty);
    installer.canInstallGate = null;
    await repo.check(manual: true);
    await repo.downloadAndInstall();
    expect(installer.installs, hasLength(1));
  });
}
