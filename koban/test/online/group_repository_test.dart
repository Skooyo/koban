import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart' show SignOutScope;
import 'package:koban/app/app_services.dart';
import 'package:koban/data/database.dart';
import 'package:koban/online/google_accounts.dart';
import 'package:koban/online/group_repository.dart';
import 'package:koban/online/group_session.dart';
import 'package:koban/rules/periods.dart';
import 'package:koban/rules/types.dart';

import '../support/fake_backend.dart';
import '../support/harness.dart';
import 'group_session_test.dart' show newExpiry, storedSession, tokenReply;

/// Gives [identity], or throws [error]. It counts the calls.
class FakeGoogleAccounts implements GoogleAccounts {
  GoogleIdentity? identity = const GoogleIdentity('id-token', 'nonce-1', 'Ali');
  GoogleSignInError? error;
  var calls = 0;

  @override
  Future<GoogleIdentity?> signIn() async {
    calls++;
    if (error != null) throw error!;
    return identity;
  }
}

http.Response jsonReply(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response fixture(String name) => http.Response(
  File('test/fixtures/online/$name').readAsStringSync(),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response empty(http.Request r) => http.Response('', 204);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBackend backend;
  late AppServices s;
  late FakeGoogleAccounts google;
  late GroupRepository repo;
  var n = 0;

  /// [signedIn]: a stored 0.1.1 session that the token route makes live.
  Future<void> open({
    bool online = true,
    bool signedIn = true,
    Duration syncDelay = const Duration(seconds: 5),
  }) async {
    backend = FakeBackend();
    s = await testServices(
      now: DateTime.utc(2026, 11, 13, 4),
      http: backend.client,
      prefs: {if (!online) 'online_features': false},
      secrets: {
        'device_token': 'test-device-token',
        if (signedIn) 'group_session': storedSession,
      },
    );
    google = FakeGoogleAccounts();
    repo = GroupRepository(
      online: s.online,
      session: s.online.session,
      google: google,
      db: s.db,
      now: s.now,
      syncDelay: syncDelay,
    );
    addTearDown(() async {
      repo.dispose();
      s.online.session.dispose();
      await s.online.supabase.dispose();
    });
    backend.on('POST', '/auth/v1/token', tokenReply);
    if (signedIn && online) {
      expect(await s.online.session.restore(), RestoreResult.restored);
      backend.requests.clear();
    }
  }

  void readRoutes() {
    backend.on(
      'GET',
      '/rest/v1/profiles',
      (r) => jsonReply([
        {'alias': 'Ali'},
      ]),
    );
    backend.on(
      'GET',
      '/rest/v1/join_requests',
      (r) => jsonReply([
        {
          'group_id': 'g1',
          'user_id': 'user-2',
          'profiles': {'alias': 'Mei'},
        },
        {
          'group_id': 'g9',
          'user_id': 'user-1',
          'created_at': '2026-11-10T01:00:00+00:00',
          'profiles': {'alias': 'Ali'},
        },
      ]),
    );
    backend.on('GET', '/rest/v1/groups', (r) => fixture('groups_select.json'));
    backend.on(
      'GET',
      '/rest/v1/removed_notices',
      (r) => jsonReply([
        {'id': 7, 'group_name': 'Kedai Group'},
      ]),
    );
  }

  void syncRoutes({String joinedAt = '2026-11-10T01:00:00+00:00'}) {
    backend.on(
      'GET',
      '/rest/v1/group_members',
      (r) => jsonReply([
        {'joined_at': joinedAt},
      ]),
    );
    backend.on('DELETE', '/rest/v1/shared_totals', empty);
    backend.on('POST', '/rest/v1/shared_totals', (r) => http.Response('', 201));
    backend.on('PATCH', '/rest/v1/profiles', empty);
  }

  void rpc(String name, String reply, [int status = 200]) => backend.on(
    'POST',
    '/rest/v1/rpc/$name',
    (r) => http.Response(
      reply,
      status,
      headers: {'content-type': 'application/json'},
    ),
  );

  List<String> calls() => [
    for (final r in backend.requests) '${r.method} ${r.url.path}',
  ];

  List<Object?> sentTotals() => jsonDecode(
    backend.requests
        .lastWhere(
          (r) => r.method == 'POST' && r.url.path == '/rest/v1/shared_totals',
        )
        .body,
  ) as List<Object?>;

  Future<void> pay(
    String amount,
    DateTime at, {
    String currency = 'MYR',
    String? category = 'food',
    TransactionType type = TransactionType.withdraw,
    ExpenseStatus status = ExpenseStatus.autoSaved,
    bool private = false,
    String? counted,
  }) {
    n++;
    return s.db
        .into(s.db.expenses)
        .insert(
          ExpensesCompanion.insert(
            id: 'e$n',
            amount: Decimal.parse(amount),
            currency: currency,
            rawNotificationText: 'test',
            sourcePackage: 'test.bank',
            notificationPostTime: at.millisecondsSinceEpoch,
            createdAt: at.millisecondsSinceEpoch,
            dedupKey: 'k$n',
            status: status,
            confidence: ParseConfidence.high,
            categoryId: Value(category),
            transactionType: type,
            privateToGroups: private,
            countedAmount: Value(
              counted == null ? null : Decimal.parse(counted),
            ),
          ),
        );
  }

  /// Waits for [done] in steps of 5 ms, at most 2 s.
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(done(), isTrue, reason: 'the condition did not come true in 2 s');
  }

  test(
    'refresh reads the alias, the groups, the requests and the removed notices',
    () async {
      await open();
      readRoutes();

      await repo.refresh();

      final st = repo.state.value;
      expect(st.userId, 'user-1');
      expect(st.alias, 'Ali');
      expect(
        st.groups.map(
          (g) => (g.id, g.name, g.code, g.ownerId, g.members, g.requests),
        ),
        [
          ('g1', 'Makan Group', 'GRP-AB12', 'user-1', 3, 1),
          ('g2', 'Trip', 'GRP-CD34', null, 1, 0),
        ],
      );
      expect(st.requests.map((r) => (r.groupId, r.userId, r.alias)), [
        ('g1', 'user-2', 'Mei'),
      ]);
      expect(st.waiting.map((r) => (r.groupId, r.sentAt)), [
        ('g9', DateTime.utc(2026, 11, 10, 1)),
      ]);
      expect(st.removedFrom, [(7, 'Kedai Group')]);
      expect((st.loading, st.message), (false, null));
      expect(repo.inGroups.value, true);
      final groups = backend.requests.firstWhere(
        (r) => r.url.path == '/rest/v1/groups',
      );
      expect(
        groups.url.queryParameters['select'],
        'id,name,code,owner_id,group_members(user_id)',
      );
      expect(groups.url.queryParameters['order'], startsWith('created_at.asc'));
      expect(backend.requests.first.url.queryParameters, {
        'select': 'alias',
        'user_id': 'eq.user-1',
      });
    },
  );

  test('each RPC status word gives the 0.1.1 message', () async {
    await open();
    readRoutes();
    syncRoutes();

    rpc('make_group', '{"status":"too_many_groups"}');
    expect(await repo.makeGroup('A'), 'You are in 5 groups, the most allowed.');
    rpc('make_group', '{"status":"bad_name"}');
    expect(
      await repo.makeGroup(''),
      'Give the group a name of 1 to 40 characters.',
    );
    rpc('make_group', '{"status":"ok"}');
    expect(await repo.makeGroup('A'), isNull);
    rpc('ask_to_join', '"unknown"');
    expect(
      await repo.askToJoin('GRP-0000'),
      'No group has this code. Check it with the person who sent it.',
    );
    rpc('ask_to_join', '"full"');
    expect(
      await repo.askToJoin('GRP-0000'),
      'This group has 10 members, the most allowed.',
    );
    rpc('answer_request', '"expired"');
    expect(
      await repo.answer(const JoinRequest('g1', 'user-2', 'Mei'), true),
      'This request is older than 7 days. Ask Mei to send it again.',
    );
    rpc('rename_group', '"not_owner"');
    expect(await repo.rename('g1', 'B'), 'Only the group owner can do this.');
    rpc('leave_group', '"use_leave"');
    expect(await repo.leave('g1'), 'Use Leave group to leave.');
    rpc('remove_member', '"not_member"');
    expect(
      await repo.remove('g1', 'user-3'),
      'This person is not in the group.',
    );
    rpc('new_group_code', '"GRP-7KQ2"');
    expect(await repo.newCode('g1'), isNull);
    rpc('new_group_code', '"not_owner"');
    expect(
      await repo.newCode('g1'),
      'Only the group owner can make a new code.',
    );
    // A server error with a JSON body is not a sign-out.
    rpc('hand_over', '{"code":"XX000","message":"internal"}', 500);
    expect(
      await repo.handOver('g1', 'user-2'),
      "Koban's server had a problem. Try again later.",
    );
  });

  test('an RPC call sends the 0.1.1 parameter names', () async {
    await open();
    readRoutes();
    syncRoutes();
    rpc('answer_request', '"ok"');

    expect(
      await repo.answer(const JoinRequest('g1', 'user-2', 'Mei'), true),
      isNull,
    );

    final r = backend.requests.first;
    expect('${r.method} ${r.url.path}', 'POST /rest/v1/rpc/answer_request');
    expect(jsonDecode(r.body), {
      'p_group': 'g1',
      'p_user': 'user-2',
      'p_approve': true,
    });
    // After the action: a refresh, then the shared totals.
    expect(
      calls(),
      containsAllInOrder([
        'GET /rest/v1/groups',
        'DELETE /rest/v1/shared_totals',
        'PATCH /rest/v1/profiles',
      ]),
    );
  });

  test('sign-in links the device token and refreshes', () async {
    await open(signedIn: false);
    readRoutes();
    rpc('link_account', '"ok"');

    expect(await repo.signIn(), isNull);

    expect(
      backend.requests.first.url.queryParameters['grant_type'],
      'id_token',
    );
    // The profile check comes first: a profile that exists is not a first sign-in.
    expect(backend.requests[1].url.path, '/rest/v1/profiles');
    final link = backend.requests[2];
    expect(link.url.path, '/rest/v1/rpc/link_account');
    expect(jsonDecode(link.body), {
      'p_device_token': 'test-device-token',
      'p_alias': 'Ali',
    });
    expect(repo.state.value.userId, 'user-1');
    expect(repo.state.value.groups, hasLength(2));
    expect(repo.state.value.namePending, false);
  });

  test('the first sign-in asks for the name until nameDone', () async {
    await open(signedIn: false);
    readRoutes();
    var profileReads = 0;
    backend.on('GET', '/rest/v1/profiles', (r) {
      // The account has no profile before link_account, and one after it.
      profileReads++;
      return jsonReply(
        profileReads == 1
            ? []
            : [
                {'alias': 'Ali'},
              ],
      );
    });
    rpc('link_account', '"ok"');

    expect(await repo.signIn(), isNull);
    expect(repo.state.value.namePending, true);
    expect(repo.state.value.alias, 'Ali');

    repo.nameDone();
    expect(repo.state.value.namePending, false);
  });

  test('sign-in without an accepted invite signs out again', () async {
    await open(signedIn: false);
    backend.on('GET', '/rest/v1/profiles', (r) => jsonReply([]));
    rpc('link_account', '"no_invite"');
    backend.on('POST', '/auth/v1/logout', empty);

    expect(
      await repo.signIn(),
      'Groups need online access. Enter your invite code in Settings first.',
    );

    expect(await s.online.secrets.groupSession(), isNull);
    expect(s.online.session.userId, isNull);
    expect(s.online.secrets.deviceToken.value, 'test-device-token');
  });

  test('a cancelled Google sign-in sends nothing and shows nothing', () async {
    await open(signedIn: false);
    google.identity = null;

    expect(await repo.signIn(), isNull);

    google.error = const GoogleSignInError(
      'Google sign-in failed. Add a Google account to this phone and try again.',
    );
    expect(
      await repo.signIn(),
      'Google sign-in failed. Add a Google account to this phone and try again.',
    );
    expect(google.calls, 2);
    expect(backend.requests, isEmpty);
    expect(repo.state.value.message, isNull);
  });

  // Ruling R3: as 0.1.1, a JWT answer shows Sign in again and keeps the stored session.
  test('an expired session on a read says Sign in again and keeps the stored session', () async {
    await open();
    final stored = await s.online.secrets.groupSession();
    readRoutes();
    backend.on(
      'GET',
      '/rest/v1/groups',
      (r) => jsonReply({'code': 'PGRST301', 'message': 'JWT expired'}, 401),
    );

    await repo.refresh();

    expect(repo.state.value.message, 'Sign in again.');
    expect(repo.state.value.userId, isNull);
    expect(repo.state.value.loading, isFalse);
    expect(await s.online.secrets.groupSession(), stored);
    expect(calls().contains('POST /auth/v1/logout'), isFalse);
  });

  test('a signed-out answer to an action says Sign in again and keeps the stored session', () async {
    await open();
    final stored = await s.online.secrets.groupSession();
    rpc('make_group', '{"code":"PGRST303","message":"JWT expired"}', 401);

    expect(await repo.makeGroup('A'), 'Sign in again.');

    expect(repo.state.value.userId, isNull);
    expect(await s.online.secrets.groupSession(), stored);
    expect(s.online.session.userId, 'user-1');
    expect(calls(), ['POST /rest/v1/rpc/make_group']);
  });

  test('a refused token refresh inside a read says Sign in again and sends no anonymous read', () async {
    await open(signedIn: false);
    await s.online.secrets.setGroupSession(storedSession);
    var tokenCalls = 0;
    backend.on('POST', '/auth/v1/token', (r) {
      tokenCalls++;
      // The first reply gives an access token that has already expired.
      if (tokenCalls == 1) {
        return http.Response(
          File('test/fixtures/online/token_response.json')
              .readAsStringSync()
              .replaceFirst(
                'ACCESS_TOKEN',
                fakeJwt(sub: 'user-1', exp: 1762000000),
              ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return jsonReply({'code': 'refresh_token_not_found', 'msg': 'x'}, 400);
    });
    readRoutes();
    expect(await s.online.session.restore(), RestoreResult.restored);

    await repo.refresh();

    expect(repo.state.value.message, 'Sign in again.');
    expect(repo.state.value.userId, isNull);
    final anonymousGets = backend.requests
        .where(
          (r) =>
              r.method == 'GET' &&
              r.headers['authorization'] ==
                  'Bearer ${s.online.config.supabaseKey}',
        )
        .length;
    expect(anonymousGets, 0);
    expect(calls(), ['POST /auth/v1/token', 'POST /auth/v1/token']);
  });

  test(
    'a refused restore during a refresh clears the groups and inGroups',
    () async {
      await open();
      readRoutes();
      await repo.refresh();
      expect(repo.state.value.groups, isNotEmpty);
      expect(repo.inGroups.value, true);
      // GoTrue loses its session. The server then refuses the stored refresh token.
      backend.on('POST', '/auth/v1/logout', empty);
      await s.online.supabase.auth.signOut(scope: SignOutScope.local);
      await s.online.secrets.setGroupSession(storedSession);
      backend.on(
        'POST',
        '/auth/v1/token',
        (r) => jsonReply({
          'code': 'refresh_token_not_found',
          'msg': 'Invalid',
        }, 400),
      );

      await repo.refresh();

      expect(repo.state.value.message, 'Sign in again.');
      expect(repo.state.value.userId, isNull);
      expect(repo.state.value.groups, isEmpty);
      expect(repo.inGroups.value, false);
    },
  );

  test('a server error on a read is tried one time, as 0.1.1', () async {
    await open();
    readRoutes();
    backend.on(
      'GET',
      '/rest/v1/groups',
      (r) => jsonReply({'code': 'PGRST000', 'message': 'busy'}, 503),
    );

    await repo.refresh();

    expect(
      repo.state.value.message,
      "Koban's server had a problem. Try again later.",
    );
    expect(repo.state.value.userId, 'user-1');
    expect(calls().where((c) => c == 'GET /rest/v1/groups').length, 1);
  });

  test("a server error on restore says Koban's server had a problem", () async {
    await open(signedIn: false);
    await s.online.secrets.setGroupSession(storedSession);
    backend.on(
      'POST',
      '/auth/v1/token',
      (r) => http.Response('{"message":"unavailable"}', 503),
    );

    await repo.refresh();

    expect(
      repo.state.value.message,
      "Koban's server had a problem. Try again later.",
    );
    expect(repo.state.value.userId, 'user-1');
    expect(await s.online.secrets.groupSession(), storedSession);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a refused session at the start says Sign in again', () async {
    await open(signedIn: false);
    await s.online.secrets.setGroupSession(storedSession);
    backend.on(
      'POST',
      '/auth/v1/token',
      (r) =>
          jsonReply({'code': 'refresh_token_not_found', 'msg': 'Invalid'}, 400),
    );

    repo.start();
    await until(() => repo.state.value.message != null);

    expect(repo.state.value.message, 'Sign in again.');
    expect(repo.state.value.userId, isNull);
    expect(calls(), ['POST /auth/v1/token']);
    expect(await s.online.secrets.groupSession(), isNull);
  });

  test('delete account calls the function and signs out', () async {
    await open();
    backend.on('POST', '/functions/v1/delete-account', empty);
    backend.on('POST', '/auth/v1/logout', empty);

    expect(await repo.deleteAccount(), isNull);

    final r = backend.requests.first;
    expect('${r.method} ${r.url.path}', 'POST /functions/v1/delete-account');
    expect(
      r.headers['authorization'],
      'Bearer ${fakeJwt(sub: 'user-1', exp: newExpiry)}',
    );
    expect(await s.online.secrets.groupSession(), isNull);
    expect(repo.state.value.userId, isNull);
    expect(repo.state.value.groups, isEmpty);
  });

  // Review Focus 3
  test('shared totals leave out money in, dismissed and private payments and are exact to the cent', () async {
    await open();
    syncRoutes();
    final wed = DateTime.utc(2026, 11, 11, 4);
    await pay('0.10', wed);
    await pay('0.20', wed);
    await pay('50.00', wed, type: TransactionType.receive);
    await pay('9.00', wed, status: ExpenseStatus.dismissed);
    await pay('7.00', wed, private: true);
    await pay('25000.00', wed, currency: 'IDR', category: 'transport');
    // A payment that counts 0.00 (all of it repaid) gives a total of 0: it is left out.
    await pay('5.00', wed, category: 'shopping', counted: '0.00');

    await repo.syncTotals();

    expect(
      sentTotals(),
      unorderedEquals([
        {
          'user_id': 'user-1',
          'currency': 'MYR',
          'period': 'week',
          'period_start': '2026-11-09',
          'category': 'Food & Dining',
          'amount': '0.30',
        },
        {
          'user_id': 'user-1',
          'currency': 'MYR',
          'period': 'month',
          'period_start': '2026-11-01',
          'category': 'Food & Dining',
          'amount': '0.30',
        },
        {
          'user_id': 'user-1',
          'currency': 'IDR',
          'period': 'week',
          'period_start': '2026-11-09',
          'category': 'Transport',
          'amount': '25000.00',
        },
        {
          'user_id': 'user-1',
          'currency': 'IDR',
          'period': 'month',
          'period_start': '2026-11-01',
          'category': 'Transport',
          'amount': '25000.00',
        },
      ]),
    );
    expect(calls(), [
      'GET /rest/v1/group_members',
      'DELETE /rest/v1/shared_totals',
      'POST /rest/v1/shared_totals',
      'PATCH /rest/v1/profiles',
    ]);
    expect(backend.requests[0].url.queryParameters, {
      'select': 'joined_at',
      'user_id': 'eq.user-1',
    });
    expect(backend.requests[1].url.queryParameters, {'user_id': 'eq.user-1'});
    expect(jsonDecode(backend.requests[3].body), {
      'totals_updated_at': '2026-11-13T04:00:00.000Z',
    });
  });

  // Review Focus 4
  test('a payment at Sunday 23:30 Malaysia time counts in that week', () async {
    await open();
    syncRoutes(joinedAt: '2026-11-02T00:00:00+00:00');
    await pay('10.00', DateTime.utc(2026, 11, 8, 15, 30));
    await pay('20.00', DateTime.utc(2026, 11, 8, 16));

    await repo.syncTotals();

    expect(
      sentTotals().cast<Map<String, Object?>>().map(
        (r) => (r['currency'], r['period'], r['period_start'], r['amount']),
      ),
      unorderedEquals([
        ('MYR', 'week', '2026-11-02', '10.00'),
        ('MYR', 'week', '2026-11-09', '20.00'),
        ('MYR', 'month', '2026-11-01', '30.00'),
      ]),
    );
  });

  test('a payment with no category goes as Uncategorized', () async {
    await open();
    syncRoutes();
    await pay('4.50', DateTime.utc(2026, 11, 12, 4), category: null);

    await repo.syncTotals();

    expect(
      sentTotals().cast<Map<String, Object?>>().map(
        (r) => (r['period'], r['category'], r['amount']),
      ),
      unorderedEquals([
        ('week', 'Uncategorized', '4.50'),
        ('month', 'Uncategorized', '4.50'),
      ]),
    );
  });

  test('a payment change starts one sync after the quiet time', () async {
    await open(syncDelay: const Duration(milliseconds: 20));
    readRoutes();
    syncRoutes();
    int deletes() =>
        calls().where((c) => c == 'DELETE /rest/v1/shared_totals').length;

    repo.start();
    await until(() => calls().contains('PATCH /rest/v1/profiles'));
    expect(deletes(), 1);

    final t = DateTime.utc(2026, 11, 12, 4);
    await pay('1.00', t);
    await pay('2.00', t);
    await pay('3.00', t);
    await until(() => deletes() == 2);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(deletes(), 2);
    expect(sentTotals().cast<Map<String, Object?>>().map((r) => r['amount']), [
      '6.00',
      '6.00',
    ]);
  });

  test(
    'loadGroup sorts members by total and keeps the requests of that group',
    () async {
      await open();
      readRoutes();
      await repo.refresh();
      backend.on(
        'GET',
        '/rest/v1/group_members',
        (r) => fixture('group_members_select.json'),
      );
      backend.on(
        'GET',
        '/rest/v1/shared_totals',
        (r) => jsonReply([
          {'user_id': 'user-1', 'category': 'Transport', 'amount': 3},
          {'user_id': 'user-1', 'category': 'Food & Dining', 'amount': 12.5},
          {'user_id': 'user-2', 'category': 'Food & Dining', 'amount': 40.1},
        ]),
      );
      backend.requests.clear();

      final d = (await repo.loadGroup('g1', Period.week, 'MYR'))!;

      expect(d.group.name, 'Makan Group');
      expect(d.members.map((m) => (m.userId, m.alias, m.total)), [
        ('user-2', 'Mei', Decimal.parse('40.1')),
        ('user-1', 'Ali', Decimal.parse('15.5')),
        ('user-3', '?', Decimal.zero),
      ]);
      expect(d.members[1].categories, [
        ('Food & Dining', Decimal.parse('12.5')),
        ('Transport', Decimal.parse('3')),
      ]);
      expect(d.members.map((m) => (m.joinedAt, m.updatedAt)), [
        (DateTime.utc(2026, 11, 11, 2, 30, 0, 500), null),
        (
          DateTime.utc(2026, 11, 10, 1),
          DateTime.utc(2026, 11, 12, 5, 59, 5, 867, 657),
        ),
        (DateTime.utc(2026, 11, 12, 3), null),
      ]);
      expect(d.requests.map((r) => (r.groupId, r.userId, r.alias)), [
        ('g1', 'user-2', 'Mei'),
      ]);
      expect(backend.requests[0].url.queryParameters, {
        'select': 'user_id,joined_at,profiles(alias,totals_updated_at)',
        'group_id': 'eq.g1',
      });
      expect(backend.requests[1].url.queryParameters, {
        'select': 'user_id,category,amount',
        'user_id': 'in.("user-1","user-2","user-3")',
        'currency': 'eq.MYR',
        'period': 'eq.week',
        'period_start': 'eq.2026-11-09',
      });
    },
  );

  // Review Focus 2
  test('with Online features off no method sends a request', () async {
    await open(online: false);

    repo.start();
    await repo.refresh();
    await repo.syncTotals();
    expect(await repo.makeGroup('A'), 'Turn on online features first.');
    expect(await repo.askToJoin('GRP-0000'), 'Turn on online features first.');
    expect(await repo.setAlias('Ali'), 'Turn on online features first.');
    expect(await repo.deleteAccount(), 'Turn on online features first.');
    expect(await repo.signIn(), 'Turn on online features first.');
    expect(await repo.loadGroup('g1', Period.month, 'MYR'), isNull);
    await repo.dismissRemoved(7);
    await repo.signOut();
    await pay('1.00', DateTime.utc(2026, 11, 12, 4));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(backend.requests, isEmpty);
    expect(google.calls, 0);
    expect(repo.state.value.online, isFalse);
  });

  test(
    'turning Online features on restores the session and refreshes',
    () async {
      await open(online: false);
      readRoutes();
      syncRoutes();
      repo.start();

      await s.settings.setOnlineFeatures(true);
      await until(() => calls().contains('PATCH /rest/v1/profiles'));

      expect(calls().first, 'POST /auth/v1/token');
      expect(
        backend.requests.first.url.queryParameters['grant_type'],
        'refresh_token',
      );
      expect(repo.state.value.online, isTrue);
      expect(repo.state.value.userId, 'user-1');
      expect(repo.state.value.groups.map((g) => g.name), [
        'Makan Group',
        'Trip',
      ]);
    },
  );
}
