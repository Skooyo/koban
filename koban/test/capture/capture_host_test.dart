import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/capture/capture_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const name = 'io.github.skooyo.koban/capture';
  const channel = MethodChannel(name);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late ChannelCaptureHost host;
  Object? reply;

  setUp(() {
    calls = [];
    reply = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply;
    });
    host = ChannelCaptureHost();
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('queue rows from the channel become typed rows', () async {
    reply = [
      {
        'id': 7,
        'logId': 'log-1',
        'packageName': 'com.maybank2u.life',
        'title': 'Maybank',
        'text':
            'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.',
        'postTime': 1761999940000,
        'notificationKey': 'k1',
      },
      {
        'id': 8,
        'logId': 'log-2',
        'packageName': 'com.maybank2u.life',
        'title': null,
        'text': 'Hello',
        'postTime': 1761999950000,
        'notificationKey': null,
      },
    ];
    final rows = await host.takeQueue(0);
    expect(calls.single.method, 'takeQueue');
    expect(calls.single.arguments, {'afterId': 0});
    expect(rows.length, 2);
    expect(rows[0].id, 7);
    expect(rows[0].logId, 'log-1');
    expect(rows[0].packageName, 'com.maybank2u.life');
    expect(rows[0].title, 'Maybank');
    expect(
      rows[0].text,
      'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.',
    );
    expect(rows[0].postTime, 1761999940000);
    expect(rows[0].notificationKey, 'k1');
    expect(rows[1].title, isNull);
    expect(rows[1].notificationKey, isNull);
  });

  test('finish sends the row id, log id, disposition name and detail', () async {
    const row = QueuedNotification(
      id: 7,
      logId: 'log-1',
      packageName: 'p',
      title: null,
      text: 't',
      postTime: 1,
      notificationKey: null,
    );
    await host.finish(
      row,
      NotificationDisposition.skippedNoRule,
      'No rule matched this text',
    );
    expect(calls.single.method, 'finish');
    expect(calls.single.arguments, {
      'id': 7,
      'logId': 'log-1',
      'disposition': 'SKIPPED_NO_RULE',
      'detail': 'No rule matched this text',
    });
  });

  test('the other calls send their argument keys', () async {
    await host.updateLog('log-1', NotificationDisposition.skippedError, 'bad');
    await host.appendLog('T', 'B', NotificationDisposition.infoOnly, 'd');
    await host.setPaymentApps({'b', 'a'});
    await host.acquireImportGate();
    await host.releaseImportGate();
    expect(calls.map((c) => c.method), [
      'updateLog',
      'appendLog',
      'setPaymentApps',
      'acquireImportGate',
      'releaseImportGate',
    ]);
    expect(calls[0].arguments, {
      'logId': 'log-1',
      'disposition': 'SKIPPED_ERROR',
      'detail': 'bad',
    });
    expect(calls[1].arguments, {
      'title': 'T',
      'body': 'B',
      'disposition': 'INFO_ONLY',
      'detail': 'd',
    });
    expect(calls[2].arguments, {
      'apps': ['a', 'b'],
    });
  });

  test('a drain call from native runs the handler', () async {
    var count = 0;
    host.onDrain(() async => count++);
    await messenger.handlePlatformMessage(
      name,
      const StandardMethodCodec().encodeMethodCall(const MethodCall('drain')),
      (_) {},
    );
    expect(count, 1);
  });

  test('the disposition names round trip', () {
    for (final d in NotificationDisposition.values) {
      expect(NotificationDisposition.fromDbName(d.dbName), d);
    }
  });
}
