import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koban/online/online_http.dart';
import 'package:supabase/supabase.dart';

void main() {
  final url = Uri.parse('https://example.invalid/rest/v1/groups');

  test('a call with no answer in time fails with a timeout', () async {
    final slow = MockClient((r) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('[]', 200);
    });
    final client = TimeoutClient(
      slow,
      timeout: const Duration(milliseconds: 10),
    );

    await expectLater(client.get(url), throwsA(isA<TimeoutException>()));
  });

  test('a call with no answer in time is aborted', () async {
    final aborted = Completer<void>();
    final never = Completer<http.StreamedResponse>();
    final slow = MockClient.streaming((r, body) {
      // The inner client sees the abort trigger and stops the call, as IOClient does.
      (r as http.Abortable).abortTrigger!.then((_) => aborted.complete());
      return never.future;
    });
    final client = TimeoutClient(
      slow,
      timeout: const Duration(milliseconds: 10),
    );

    await expectLater(client.get(url), throwsA(isA<TimeoutException>()));
    await aborted.future.timeout(const Duration(seconds: 1));
    expect(aborted.isCompleted, isTrue);
  });

  test(
    'a call that answers in time gives the answer and is not aborted',
    () async {
      http.BaseRequest? seen;
      final fast = MockClient.streaming((r, body) async {
        seen = r;
        final text = await body.bytesToString();
        return http.StreamedResponse(
          Stream.value('$text ok'.codeUnits),
          201,
          headers: {'x-answer': '1'},
        );
      });
      final client = TimeoutClient(fast);

      final response = await client.post(
        url,
        headers: {'apikey': 'test-key'},
        body: 'hello',
      );

      expect((response.statusCode, response.body), (201, 'hello ok'));
      expect(response.headers['x-answer'], '1');
      expect(seen!.headers['apikey'], 'test-key');
      expect(seen!.method, 'POST');
      var aborted = false;
      unawaited(
        (seen! as http.Abortable).abortTrigger!.then((_) => aborted = true),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(aborted, isFalse);
    },
  );

  test('connection errors count as no connection, other errors do not', () {
    expect(isNoConnection(http.ClientException('x', url)), isTrue);
    expect(isNoConnection(const SocketException('x')), isTrue);
    expect(isNoConnection(TimeoutException('x')), isTrue);
    expect(isNoConnection(AuthRetryableFetchException()), isTrue);
    expect(isNoConnection(const FormatException('x')), isFalse);
    expect(isNoConnection(AuthException('x', statusCode: '400')), isFalse);
  });
}
