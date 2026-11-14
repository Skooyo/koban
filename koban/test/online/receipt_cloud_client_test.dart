import 'dart:convert';
import 'dart:io' show HandshakeException;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koban/online/online_config.dart';
import 'package:koban/online/receipt_cloud_client.dart';
import 'package:koban/rules/receipt_cloud.dart'
    show CloudReadFailed, CloudReadOk;

import '../support/fake_backend.dart';
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

  group('read', () {
    const path = '/cache/r.jpg';
    const token = 'test-device-token';
    final goodReply = jsonEncode({
      'merchant': 'Kedai Contoh',
      'date': '2026-11-13',
      'items': [
        {'name': 'Nasi lemak', 'quantity': 1, 'price': 20.0},
        {'name': 'Teh ais', 'quantity': 1, 'price': 4.0},
      ],
      'total': 24.0,
      'readsLeftToday': 7,
    });

    Future<(ReceiptCloudClient, FakeBackend)> readClient({
      Future<Uint8List?> Function(String)? shrink,
      Map<String, Object> prefs = const {},
    }) async {
      final backend = FakeBackend();
      final s = await testServices(http: backend.client, prefs: prefs);
      return (
        ReceiptCloudClient(
          s.online,
          shrink: shrink ?? (_) async => Uint8List.fromList([1, 2, 3]),
        ),
        backend,
      );
    }

    test('a good Claude read gives the items and the reads left', () async {
      final (client, backend) = await readClient();
      backend.on(
        'POST',
        '/functions/v1/read-receipt',
        (r) => http.Response(goodReply, 200),
      );

      final r = await client.read(path, token) as CloudReadOk;

      expect(r.readsLeft, 7);
      expect(r.read.accepted, true);
      expect(r.read.draft.merchant, 'Kedai Contoh');
      expect(r.read.draft.items.map((i) => i.name), ['Nasi lemak', 'Teh ais']);
      final req = backend.requests.single;
      expect(req.headers['authorization'], 'Bearer test-device-token');
      expect(req.headers['content-type'], 'image/jpeg');
      expect(req.headers.containsKey('apikey'), false);
      expect(req.bodyBytes, [1, 2, 3]);
    });

    test('each failure gives the 0.1.1 reason and flags', () async {
      const notReachable = 'Claude was not reachable.';
      const couldNotRead =
          "Claude could not read this receipt. This used 1 of today's reads.";
      final (client, backend) = await readClient();
      var answer = http.Response('', 500);
      backend.on('POST', '/functions/v1/read-receipt', (r) => answer);
      for (final (status, body, why, revoked, used) in [
        (401, '{}', 'Your invite code is no longer active.', true, false),
        (
          429,
          '{"limit":"all"}',
          "Koban reached today's Claude limit.",
          false,
          false,
        ),
        (
          429,
          '{"limit":"code"}',
          'Your invite code used all its Claude reads for today.',
          false,
          false,
        ),
        (429, '{}', 'You used your 10 Claude reads for today.', false, false),
        (502, '', couldNotRead, false, true),
        (504, '', couldNotRead, false, true),
        (200, 'not json', couldNotRead, false, true),
        (500, '', notReachable, false, false),
      ]) {
        answer = http.Response(body, status);
        final r = await client.read(path, token) as CloudReadFailed;
        final reason = '$status $body';
        expect(r.why, why, reason: reason);
        expect(r.tokenRevoked, revoked, reason: reason);
        expect(r.usedRead, used, reason: reason);
      }
    });

    test('no connection gives not reachable', () async {
      final (client, backend) = await readClient();
      backend.on(
        'POST',
        '/functions/v1/read-receipt',
        (r) => throw http.ClientException('no route'),
      );

      final r = await client.read(path, token) as CloudReadFailed;

      expect(r.why, 'Claude was not reachable.');
      expect(r.usedRead, false);
    });

    test('a TLS failure gives not reachable', () async {
      final (client, backend) = await readClient();
      backend.on(
        'POST',
        '/functions/v1/read-receipt',
        (r) => throw const HandshakeException('test'),
      );

      final r = await client.read(path, token) as CloudReadFailed;

      expect(r.why, 'Claude was not reachable.');
      expect(r.usedRead, false);
    });

    test('a photo that cannot be opened sends nothing', () async {
      final (client, backend) = await readClient(shrink: (_) async => null);

      final r = await client.read(path, token) as CloudReadFailed;

      expect(r.why, 'Claude was not reachable.');
      expect(backend.requests, isEmpty);
    });

    test('with Online features off the photo is not sent', () async {
      var shrinks = 0;
      final (client, backend) = await readClient(
        prefs: {'online_features': false},
        shrink: (_) async {
          shrinks++;
          return Uint8List.fromList([1]);
        },
      );

      final r = await client.read(path, token) as CloudReadFailed;

      expect(r.why, ReceiptCloudClient.onlineOff);
      expect(backend.requests, isEmpty);
      expect(shrinks, 0);
    });
  });
}
