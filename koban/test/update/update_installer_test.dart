import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/update/update_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const name = 'io.github.skooyo.koban/update';
  const channel = MethodChannel(name);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) =>
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return reply(call);
      });

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('install sends the path and the version code', () async {
    answer((_) => null);
    await ChannelUpdateInstaller().install('/c/updates/koban-9.apk', 9);
    expect(calls.single.method, 'install');
    expect(calls.single.arguments, {
      'path': '/c/updates/koban-9.apk',
      'versionCode': 9,
    });
  });

  test('a refused APK becomes NotKobanApk', () async {
    answer((_) => throw PlatformException(code: 'NOT_KOBAN_APK'));
    await expectLater(
      ChannelUpdateInstaller().install('/c/updates/koban-9.apk', 9),
      throwsA(isA<NotKobanApk>()),
    );
  });

  test('the native status comes back typed', () async {
    final seen = <(InstallStatus, String?)>[];
    ChannelUpdateInstaller().onStatus((s, m) => seen.add((s, m)));
    await messenger.handlePlatformMessage(
      name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('installStatus', {
          'status': 'pendingUserAction',
          'message': null,
        }),
      ),
      (_) {},
    );
    expect(seen, [(InstallStatus.pendingUserAction, null)]);
  });

  test('success and an unknown status come back typed', () async {
    final seen = <(InstallStatus, String?)>[];
    ChannelUpdateInstaller().onStatus((s, m) => seen.add((s, m)));
    for (final status in ['success', 'other']) {
      await messenger.handlePlatformMessage(
        name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('installStatus', {'status': status, 'message': 'm'}),
        ),
        (_) {},
      );
    }
    expect(seen, [(InstallStatus.success, 'm'), (InstallStatus.failure, 'm')]);
  });
}
