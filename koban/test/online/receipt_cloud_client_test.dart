import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koban/online/online_config.dart';
import 'package:koban/online/receipt_cloud_client.dart';

import '../support/harness.dart';

Future<(ReceiptCloudClient, List<http.Request>)> clientFor(
  Future<http.Response> Function(http.Request) answer, {
  Map<String, Object> prefs = const {},
}) async {
  final seen = <http.Request>[];
  final s = await testServices(
    prefs: prefs,
    http: MockClient((r) {
      seen.add(r);
      return answer(r);
    }),
  );
  return (s.online.receiptCloud, seen);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a good code gives the device token', () async {
    final (client, seen) = await clientFor(
      (r) async => http.Response('{"deviceToken":"test-device-token"}', 200),
    );

    final r = await client.register(' k7qx-m2pa ');

    expect((r as RegistrationOk).deviceToken, 'test-device-token');
    expect(seen, hasLength(1));
    expect(seen.single.method, 'POST');
    expect(seen.single.url, OnlineConfig.test.function('register'));
    expect(jsonDecode(seen.single.body), {'inviteCode': 'K7QX-M2PA'});
    expect(seen.single.headers['content-type'], startsWith('application/json'));
    expect(seen.single.headers['authorization'], isNull);
    expect(seen.single.headers['apikey'], isNull);
  });

  test('each refusal gives the 0.1.1 message', () async {
    for (final (status, text) in [
      (400, 'The invite code looks like XXXX-XXXX.'),
      (429, 'Too many tries. Try again in an hour.'),
      (403, 'Invite code not accepted.'),
      (500, "Koban's server had a problem. Try again later."),
    ]) {
      final (client, seen) = await clientFor(
        (r) async => http.Response('{}', status),
      );
      final r = await client.register('K7QX-M2PA');
      expect((r as RegistrationFailed).message, text, reason: '$status');
      expect(seen, hasLength(1));
    }
  });

  test('no connection says so', () async {
    final (client, seen) = await clientFor(
      (r) async => throw http.ClientException('no route'),
    );

    final r = await client.register('K7QX-M2PA');

    expect(
      (r as RegistrationFailed).message,
      "Could not reach Koban's server. Check the internet connection.",
    );
    expect(seen, hasLength(1));
  });

  test('with Online features off no request is sent', () async {
    final (client, seen) = await clientFor(
      (r) async => fail('unexpected request'),
      prefs: {'online_features': false},
    );

    final r = await client.register('K7QX-M2PA');

    expect(
      (r as RegistrationFailed).message,
      'Turn on online features in Settings to read with Claude.',
    );
    expect(seen, isEmpty);
  });
}
