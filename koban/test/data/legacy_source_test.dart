import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/legacy_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('io.github.skooyo.koban/legacy');

  void mock(Object? Function(String method) answer) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => answer(call.method));
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('channel values become Dart types', () async {
    mock((_) => <Object?, Object?>{
          'payment_app_allowlist': <Object?>['a', 'b'],
          'dark_mode': false,
          'last_update_check': 1762300000000,
        });
    final s = await ChannelLegacySource().readSettings();
    expect(s['payment_app_allowlist'], isA<List<String>>());
    expect(s, {
      'payment_app_allowlist': ['a', 'b'],
      'dark_mode': false,
      'last_update_check': 1762300000000,
    });
  });

  test('the database path comes from the channel', () async {
    mock((_) => '/data/user/0/io.github.skooyo.koban/databases/expense_tracker.db');
    expect(await ChannelLegacySource().databasePath(),
        '/data/user/0/io.github.skooyo.koban/databases/expense_tracker.db');
  });
}
