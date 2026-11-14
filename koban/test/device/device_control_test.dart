import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/user_error.dart';
import 'package:koban/device/device_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('io.github.skooyo.koban/device');
  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return reply(call);
      });

  setUp(calls.clear);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('installed apps come back as typed rows with their icon bytes', () async {
    answer(
      (_) => [
        {
          'packageName': 'com.maybank2u.life',
          'label': 'MAE',
          'icon': Uint8List.fromList([1, 2, 3]),
        },
        {'packageName': 'x.y', 'label': 'XY', 'icon': null},
      ],
    );
    final apps = await DeviceControl().installedApps();
    expect(calls.single.method, 'installedApps');
    expect(apps.map((a) => a.packageName), ['com.maybank2u.life', 'x.y']);
    expect(apps.map((a) => a.label), ['MAE', 'XY']);
    expect(apps.first.icon, Uint8List.fromList([1, 2, 3]));
    expect(apps.last.icon, isNull);
  });

  test('app labels send the package list and give the label map', () async {
    answer((_) => {'x.y': 'x.y'});
    final labels = await DeviceControl().appLabels(['x.y']);
    expect(calls.single.method, 'appLabels');
    expect(calls.single.arguments, {'packages': ['x.y']});
    expect(labels, {'x.y': 'x.y'});
  });

  test('share text sends the text and the chooser title', () async {
    answer((_) => null);
    await DeviceControl().shareText('Kedai Contoh, 13 Nov 2026');
    expect(calls.single.method, 'shareText');
    expect(calls.single.arguments, {
      'text': 'Kedai Contoh, 13 Nov 2026',
      'chooserTitle': 'Share summary',
    });
  });

  test('a gallery error becomes a user error with the native text', () async {
    answer(
      (_) => throw PlatformException(
        code: 'GALLERY',
        message: "That file isn't an image.",
      ),
    );
    await expectLater(
      DeviceControl().saveImageToGallery('/tmp/a.img', 'qr.jpg'),
      throwsA(
        isA<KobanUserError>().having(
          (e) => e.message,
          'message',
          "That file isn't an image.",
        ),
      ),
    );
    expect(calls.single.arguments, {
      'path': '/tmp/a.img',
      'displayName': 'qr.jpg',
    });
  });

  test('a gallery error with another text is rethrown unchanged', () async {
    answer(
      (_) => throw PlatformException(
        code: 'GALLERY',
        message: "Couldn't save to gallery.",
      ),
    );
    await expectLater(
      DeviceControl().saveImageToGallery('/tmp/a.img', 'qr.jpg'),
      throwsA(
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'GALLERY')
            .having((e) => e.message, 'message', "Couldn't save to gallery."),
      ),
    );
  });

  test('another platform error is rethrown unchanged', () async {
    answer((_) => throw PlatformException(code: 'NATIVE_ERROR', message: 'x'));
    await expectLater(
      DeviceControl().saveImageToGallery('/tmp/a.img', 'qr.jpg'),
      throwsA(
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'NATIVE_ERROR')
            .having((e) => e.message, 'message', 'x'),
      ),
    );
  });

  test('online config comes back typed', () async {
    answer(
      (_) => {
        'supabaseUrl': 'https://test.supabase.co',
        'supabaseKey': 'test-key',
        'googleWebClientId': 'test-client',
      },
    );
    final c = await DeviceControl().onlineConfig();
    expect(calls.single.method, 'onlineConfig');
    expect(
      (c.supabaseUrl, c.supabaseKey, c.googleWebClientId),
      ('https://test.supabase.co', 'test-key', 'test-client'),
    );
    expect(
      c.function('register'),
      Uri.parse('https://test.supabase.co/functions/v1/register'),
    );
  });

  test('relative time sends the time and now', () async {
    answer((_) => '3 hours ago');
    expect(await DeviceControl().relativeTime(1, 2), '3 hours ago');
    expect(calls.single.method, 'relativeTime');
    expect(calls.single.arguments, {'time': 1, 'now': 2});
  });
}
