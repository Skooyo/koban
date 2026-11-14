import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:koban/app/app_services.dart';
import 'package:koban/online/google_accounts.dart';
import 'package:koban/online/group_session.dart';
import 'package:koban/online/secret_store.dart';
import 'package:supabase/supabase.dart'
    show AuthException, AuthRetryableFetchException;

import '../support/fake_backend.dart';
import '../support/harness.dart';

/// The 0.1.1 session JSON. Its access token expired long ago.
const storedSession =
    '{"access_token":"old","refresh_token":"r1","expires_at":1762000000,"user_id":"user-1"}';

/// The expiry of the new access token: 1 Jan 2100, so GoTrue sees a live token.
const newExpiry = 4102444800;

/// The synthetic GoTrue token reply with refresh token `r2` for `user-1`.
http.Response tokenReply(http.Request r) => http.Response(
  File('test/fixtures/online/token_response.json')
      .readAsStringSync()
      .replaceFirst('ACCESS_TOKEN', fakeJwt(sub: 'user-1', exp: newExpiry)),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBackend backend;
  late AppServices s;
  late SecretStore secrets;
  late GroupSession session;

  Future<void> open({bool stored = true, bool online = true}) async {
    backend = FakeBackend();
    s = await testServices(
      now: DateTime.utc(2026, 11, 13, 4),
      http: backend.client,
      prefs: {if (!online) 'online_features': false},
      secrets: {
        'device_token': 'test-device-token',
        if (stored) 'group_session': storedSession,
      },
    );
    secrets = s.online.secrets;
    session = s.online.session;
    addTearDown(() async {
      session.dispose();
      await s.online.supabase.dispose();
    });
  }

  // Review Focus 1
  test('a stored 0.1.1 session with an old access token comes back after one refresh', () async {
    await open();
    backend.on('POST', '/auth/v1/token', tokenReply);

    expect(await session.restore(), RestoreResult.restored);

    expect(
      backend.requests.single.url.queryParameters['grant_type'],
      'refresh_token',
    );
    expect(jsonDecode(backend.requests.single.body), {'refresh_token': 'r1'});
    expect(session.userId, 'user-1');
    final stored = jsonDecode((await secrets.groupSession())!);
    expect(
      (stored['refresh_token'], stored['user_id'], stored['expires_at']),
      ('r2', 'user-1', newExpiry),
    );
  });

  test(
    'a refused refresh token removes the session and keeps the device token',
    () async {
      await open();
      backend.on(
        'POST',
        '/auth/v1/token',
        (r) => http.Response(
          '{"code":"refresh_token_not_found","msg":"Invalid Refresh Token: Refresh Token Not Found"}',
          400,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(await session.restore(), RestoreResult.refused);

      expect(backend.requests, hasLength(1));
      expect(await secrets.groupSession(), isNull);
      expect(secrets.deviceToken.value, 'test-device-token');
      expect(session.userId, isNull);
      expect(session.hasStoredSession, isFalse);
    },
  );

  test('no connection keeps the stored session for the next try', () async {
    await open();
    backend.on(
      'POST',
      '/auth/v1/token',
      (r) => throw http.ClientException('no connection'),
    );

    expect(await session.restore(), RestoreResult.noConnection);

    // GoTrue tries again with a back-off, so only the first request is certain.
    expect(backend.requests, isNotEmpty);
    expect(await secrets.groupSession(), storedSession);
    expect(session.userId, 'user-1');
    expect(session.hasStoredSession, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  // Review Focus 2
  test('with Online features off restore sends nothing', () async {
    await open(online: false);

    expect(await session.restore(), RestoreResult.none);

    expect(backend.requests, isEmpty);
    expect(await secrets.groupSession(), storedSession);
  });

  test('nothing stored sends nothing', () async {
    await open(stored: false);

    expect(await session.restore(), RestoreResult.none);

    expect(backend.requests, isEmpty);
    expect(session.userId, isNull);
    expect(session.hasStoredSession, isFalse);
  });

  test(
    'Google sign-in sends the raw nonce and stores the new session',
    () async {
      await open(stored: false);
      backend.on('POST', '/auth/v1/token', tokenReply);

      final userId = await session.signInWithIdToken(
        const GoogleIdentity('id-token', 'nonce-1', 'Ali'),
      );

      expect(userId, 'user-1');
      final r = backend.requests.single;
      expect(r.url.queryParameters['grant_type'], 'id_token');
      expect(jsonDecode(r.body), containsPair('nonce', 'nonce-1'));
      expect(jsonDecode(r.body), containsPair('provider', 'google'));
      expect(jsonDecode(r.body), containsPair('id_token', 'id-token'));
      expect(
        jsonDecode((await secrets.groupSession())!)['refresh_token'],
        'r2',
      );
      expect(session.userId, 'user-1');
      // The live session comes back with no request.
      expect(await session.restore(), RestoreResult.restored);
      expect(backend.requests, hasLength(1));
    },
  );

  test('sign out removes the stored session', () async {
    await open(stored: false);
    backend.on('POST', '/auth/v1/token', tokenReply);
    backend.on('POST', '/auth/v1/logout', (r) => http.Response('', 204));
    await session.signInWithIdToken(
      const GoogleIdentity('id-token', 'nonce-1', 'Ali'),
    );

    await session.signOut();

    expect(await secrets.groupSession(), isNull);
    expect(session.userId, isNull);
    expect(session.hasStoredSession, isFalse);
    expect(s.online.supabase.auth.currentSession, isNull);
    await pumpEventQueue();
    expect(backend.requests.last.url.path, '/auth/v1/logout');
    expect(backend.requests.last.url.queryParameters['scope'], 'local');
    expect(secrets.deviceToken.value, 'test-device-token');
  });

  test('a server error on restore keeps the stored session', () async {
    await open();
    backend.on(
      'POST',
      '/auth/v1/token',
      (r) => http.Response('{"message":"unavailable"}', 503),
    );

    // 0.1.1 showed the server-problem text, so the error goes to the caller.
    await expectLater(
      session.restore(),
      throwsA(
        isA<AuthRetryableFetchException>().having(
          (e) => e.statusCode,
          'statusCode',
          '503',
        ),
      ),
    );

    expect(await secrets.groupSession(), storedSession);
    expect(session.userId, 'user-1');
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a refresh reply that is not JSON removes the session', () async {
    await open();
    backend.on(
      'POST',
      '/auth/v1/token',
      (r) => http.Response('<html>Not found</html>', 404),
    );

    expect(await session.restore(), RestoreResult.refused);

    expect(await secrets.groupSession(), isNull);
    expect(session.userId, isNull);
    expect(secrets.deviceToken.value, 'test-device-token');
  });

  // Review Focus 2
  test('with Online features off sign-in and sign-out send nothing', () async {
    await open(stored: false);
    backend.on('POST', '/auth/v1/token', tokenReply);
    await session.signInWithIdToken(
      const GoogleIdentity('id-token', 'nonce-1', 'Ali'),
    );
    backend.requests.clear();
    await s.settings.setOnlineFeatures(false);

    await expectLater(
      session.signInWithIdToken(
        const GoogleIdentity('id-token', 'nonce-1', 'Ali'),
      ),
      throwsA(isA<AuthException>()),
    );
    await session.signOut();
    await pumpEventQueue();

    expect(backend.requests, isEmpty);
    expect(await secrets.groupSession(), isNull);
  });

  test('the alias is the given name of the token, else the display name, else Friend', () {
    expect(
      aliasOf(fakeJwt(sub: 'u', exp: 1, givenName: 'Ali'), 'Ali Bin Abu'),
      'Ali',
    );
    expect(aliasOf(fakeJwt(sub: 'u', exp: 1), 'Ali Bin Abu'), 'Ali Bin Abu');
    expect(aliasOf(fakeJwt(sub: 'u', exp: 1), null), 'Friend');
  });
}
