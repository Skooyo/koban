import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A fake Supabase server for tests. It records each request and answers with the
/// route of [on]. A request with no route fails the test in the tear-down
/// (an app catch can hide a failure in the request, a tear-down cannot be hidden).
class FakeBackend {
  FakeBackend() {
    client = MockClient((r) async {
      requests.add(r);
      final reply = _routes['${r.method} ${r.url.path}'];
      if (reply != null) {
        // A real client gives the request with the response. PostgREST reads it.
        final res = reply(r);
        return http.Response.bytes(
          res.bodyBytes,
          res.statusCode,
          headers: res.headers,
          request: r,
        );
      }
      _unexpected.add('${r.method} ${r.url.path}');
      fail('unexpected request ${r.method} ${r.url.path}');
    });
    addTearDown(
      () => expect(_unexpected, isEmpty, reason: 'requests with no route'),
    );
  }

  late final MockClient client;
  final List<http.Request> requests = [];
  final _routes = <String, http.Response Function(http.Request r)>{};
  final _unexpected = <String>[];

  /// Answers each [method] request to [path] (the path without the query) with [reply].
  void on(
    String method,
    String path,
    http.Response Function(http.Request r) reply,
  ) => _routes['$method $path'] = reply;
}

/// An unsigned JWT for tests only. [exp] is in seconds since the epoch.
String fakeJwt({required String sub, required int exp, String? givenName}) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'none', 'typ': 'JWT'})}.'
      '${part({'sub': sub, 'exp': exp, 'given_name': ?givenName})}.'
      'test-signature';
}
