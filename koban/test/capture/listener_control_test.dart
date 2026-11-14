import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/capture/capture_host.dart';
import 'package:koban/capture/listener_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ListenerControl.channelName);
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

  test('reconnect gives the native result', () async {
    answer((_) => 'THROTTLED');
    expect(await ListenerControl().reconnect(), ReconnectResult.throttled);
    expect(calls.single.method, 'reconnect');
  });

  test('the log comes back as typed rows', () async {
    answer(
      (_) => [
        {
          'id': 'id-1',
          'packageName': 'com.maybank2u.life',
          'title': 'Maybank',
          'body':
              'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.',
          'postTime': 1761999940000,
          'capturedAt': 1761999940500,
          'event': 'POSTED',
          'disposition': 'WAITING',
          'detail': 'RESTORAN CONTOH · RM 15.00',
        },
      ],
    );
    final rows = await ListenerControl().recentNotifications();
    expect(calls.single.method, 'recentNotifications');
    expect(rows.length, 1);
    final r = rows.single;
    expect(r.id, 'id-1');
    expect(r.packageName, 'com.maybank2u.life');
    expect(r.title, 'Maybank');
    expect(
      r.body,
      'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.',
    );
    expect(r.postTime, 1761999940000);
    expect(r.capturedAt, 1761999940500);
    expect(r.event, CaptureEvent.posted);
    expect(r.disposition, NotificationDisposition.waiting);
    expect(r.detail, 'RESTORAN CONTOH · RM 15.00');
  });
}
