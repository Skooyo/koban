import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/online/google_accounts.dart';
import 'package:koban/online/group_repository.dart';
import 'package:koban/screens/groups/group_screen.dart';
import 'package:koban/screens/groups/groups_screen.dart';
import 'package:koban/screens/groups/groups_view_model.dart';
import 'package:koban/ui/kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../online/group_repository_test.dart'
    show FakeGoogleAccounts, empty, fixture, jsonReply;
import '../online/group_session_test.dart' show storedSession, tokenReply;
import '../support/fake_backend.dart';
import '../support/harness.dart';

/// A Google sign-in that waits for [gate], then gives the account.
class GatedGoogleAccounts extends FakeGoogleAccounts {
  final gate = Completer<void>();

  @override
  Future<GoogleIdentity?> signIn() async {
    await gate.future;
    return super.signIn();
  }
}

/// A Google sign-in that waits for [gate]. The person then cancels.
class SlowGoogleAccounts extends FakeGoogleAccounts {
  final gate = Completer<void>();

  @override
  Future<GoogleIdentity?> signIn() async {
    calls++;
    await gate.future;
    return null;
  }
}

void main() {
  late FakeBackend backend;

  /// [stored]: a stored 0.1.1 session that the token route makes live.
  /// [tokenWait]: the token route answers after this future.
  Future<AppServices> open({
    bool online = true,
    bool stored = true,
    bool invite = true,
    GoogleAccounts? google,
    Future<void>? tokenWait,
  }) async {
    backend = FakeBackend();
    backend.on('POST', '/auth/v1/token', tokenReply);
    final fake = backend.client;
    final s = await testServices(
      now: DateTime.utc(2026, 11, 13, 4),
      http: tokenWait == null
          ? fake
          : MockClient((r) async {
              if (r.url.path == '/auth/v1/token') await tokenWait;
              // [r] is finalized: the fake backend gets a copy.
              final copy = http.Request(r.method, r.url)
                ..headers.addAll(r.headers)
                ..bodyBytes = r.bodyBytes;
              return http.Response.fromStream(await fake.send(copy));
            }),
      google: google ?? FakeGoogleAccounts(),
      prefs: {if (!online) 'online_features': false},
      secrets: {
        if (invite) 'device_token': 'test-device-token',
        if (stored) 'group_session': storedSession,
      },
    );
    // The tab starts the repository. Its sync timer stops after the test.
    addTearDown(() => s.online.groups.dispose());
    return s;
  }

  /// The routes of a refresh and of the shared totals sync.
  void groupRoutes() {
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
          'created_at': '2026-11-10T12:00:00+00:00',
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
    backend.on(
      'GET',
      '/rest/v1/group_members',
      (r) => jsonReply([
        {'joined_at': '2026-11-10T01:00:00+00:00'},
      ]),
    );
    backend.on('DELETE', '/rest/v1/shared_totals', empty);
    backend.on('PATCH', '/rest/v1/profiles', empty);
  }

  List<String> calls() => [
    for (final r in backend.requests) '${r.method} ${r.url.path}',
  ];

  /// Starts the app and shows the Groups tab.
  Future<void> showGroups(
    WidgetTester tester,
    AppServices s, {
    double textScale = 1,
    bool tall = true,
  }) async {
    // A tall screen: the buttons sit under the list.
    if (tall) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await pumpKoban(tester, s, textScale: textScale);
    HomeShell.of(tester.element(find.byType(IndexedStack)))
        .select(KobanTab.groups);
    await tester.pumpAndSettle();
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  testWidgets('with Online features off the tab offers to turn them on', (
    tester,
  ) async {
    final s = await open(online: false);
    await showGroups(tester, s);

    expect(find.text('Online features are off'), findsOneWidget);
    expect(
      find.text(
        'Groups need online features. While they are off, Koban makes no network calls.',
      ),
      findsOneWidget,
    );
    expect(backend.requests, isEmpty);
    expect(find.byTooltip('Account'), findsNothing);

    groupRoutes();
    await tester.tap(find.text('Turn on online features'));
    await tester.pumpAndSettle();

    expect(s.settings.onlineFeatures.value, true);
    expect(await SharedPreferencesAsync().getBool('online_features'), true);
    expect(calls().first, 'POST /auth/v1/token');
    expect(calls(), contains('GET /rest/v1/groups'));
    expect(find.text('Makan Group'), findsOneWidget);
  });

  testWidgets('signed out the tab offers Google sign-in', (tester) async {
    final s = await open(stored: false);
    await showGroups(tester, s);

    expect(find.text('Sign in to see your groups.'), findsOneWidget);
    expect(find.text('Compare spending with friends'), findsOneWidget);
    expect(
      find.text(
        "Members see each other's totals per category, for each week and month.",
      ),
      findsOneWidget,
    );
    expect(
      find.text('Shared: category totals, week and month'),
      findsOneWidget,
    );
    expect(
      find.text('Never shared: single payments, shops, times, notes, Received'),
      findsOneWidget,
    );
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(
      find.text('Groups use the invite code of this phone.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Account'), findsNothing);
    expect(backend.requests, isEmpty);
  });

  // Review Focus 1, on screen
  testWidgets(
    'a refused 0.1.1 session shows the sign-in page and Sign in again',
    (tester) async {
      final s = await open();
      backend.on(
        'POST',
        '/auth/v1/token',
        (r) => http.Response(
          '{"code":"refresh_token_not_found","msg":"Invalid Refresh Token: Refresh Token Not Found"}',
          400,
          headers: {'content-type': 'application/json'},
        ),
      );
      await showGroups(tester, s);

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Sign in again.'),
        ),
        findsOneWidget,
      );
      expect(calls(), ['POST /auth/v1/token']);
      expect(s.online.secrets.deviceToken.value, 'test-device-token');
      expect(await s.online.secrets.groupSession(), isNull);

      // One time: the message does not come back after the snackbar closes.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Sign in again.'), findsNothing);
    },
  );

  testWidgets('a slow restore shows the groups page while it waits', (
    tester,
  ) async {
    // A restore with no connection can take about 12 s. Here the token route waits for [answer].
    final answer = Completer<void>();
    final s = await open(tokenWait: answer.future);
    groupRoutes();
    await pumpKoban(tester, s);
    HomeShell.of(tester.element(find.byType(IndexedStack)))
        .select(KobanTab.groups);
    await tester.pump();
    await tester.pump();

    expect(find.text('Sign in with Google'), findsNothing);
    expect(find.text('Make a group'), findsOneWidget);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    answer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Makan Group'), findsOneWidget);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  // Review Focus 5
  testWidgets('two fast taps on Sign in with Google start one sign-in', (
    tester,
  ) async {
    final google = SlowGoogleAccounts();
    final s = await open(stored: false, google: google);
    await showGroups(tester, s);

    final button = find.text('Sign in with Google');
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();

    expect(google.calls, 1);
    expect(find.text('Signing in…'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);

    google.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(google.calls, 1);
    expect(backend.requests, isEmpty);
  });

  testWidgets('the group list shows members, owner and requests', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final s = await open();
    groupRoutes();
    await showGroups(tester, s);

    expect(find.byTooltip('Account'), findsOneWidget);
    expect(find.text('Makan Group'), findsOneWidget);
    expect(find.text('3 members · you are the group owner'), findsOneWidget);
    expect(find.text('1 join request'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('1 member'), findsOneWidget);
    expect(
      find.text(
        'You are in no groups yet. Make a group and share its code, or join a friend\'s group with their code.',
      ),
      findsNothing,
    );
    expect(find.text('Up to 5 groups, 10 members in each.'), findsOneWidget);
    // My own request waits for the group owner. The owner's badge counts only the other requests.
    expect(find.text('Waiting for the group owner'), findsOneWidget);
    expect(find.text('Sent Tue, 10 Nov. It ends in 5 days.'), findsOneWidget);
    final row = tester.getSemantics(
      find.ancestor(
        of: find.text('Makan Group'),
        matching: find.byType(KobanRow),
      ),
    );
    expect(row.hintOverrides?.onTapHint, 'Open group');
    handle.dispose();
  });

  // Review Focus 5
  testWidgets('Make a group sends the name and refreshes', (tester) async {
    final s = await open();
    groupRoutes();
    backend.on(
      'POST',
      '/rest/v1/rpc/make_group',
      (r) => jsonReply({'status': 'ok', 'id': 'g1', 'code': 'GRP-ZZZ9'}),
    );
    await showGroups(tester, s);
    final groupsBefore = calls()
        .where((c) => c == 'GET /rest/v1/groups')
        .length;

    // Two fast taps open one dialog.
    await tester.tap(find.text('Make a group'));
    await tester.tap(find.text('Make a group'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(inDialog('Make a group'), findsOneWidget);
    expect(inDialog('0 of 40'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Lunch  ');
    await tester.pump();
    expect(inDialog('5 of 40'), findsOneWidget);
    await tester.tap(inDialog('Make group'));
    await tester.tap(inDialog('Make group'));
    await tester.pumpAndSettle();

    final made = backend.requests
        .where((r) => r.url.path == '/rest/v1/rpc/make_group')
        .toList();
    expect(made, hasLength(1));
    expect(jsonDecode(made.single.body), {'p_name': 'Lunch'});
    // The new group opens, with a snackbar that says it was made.
    expect(
      calls().where((c) => c == 'GET /rest/v1/groups').length,
      greaterThan(groupsBefore),
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(GroupScreen), findsOneWidget);
    expect(find.text('Lunch made'), findsOneWidget);
  });

  testWidgets('Make a group error shows under the field in the open dialog', (
    tester,
  ) async {
    final s = await open();
    groupRoutes();
    backend.on(
      'POST',
      '/rest/v1/rpc/make_group',
      (r) => jsonReply({'status': 'too_many_groups'}),
    );
    await showGroups(tester, s);

    await tester.tap(find.text('Make a group'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lunch');
    await tester.pump();
    await tester.tap(inDialog('Make group'));
    await tester.pumpAndSettle();

    expect(inDialog('You are in 5 groups, the most allowed.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Lunch',
    );
  });

  testWidgets('Join a group shows Request sent after an ok answer', (
    tester,
  ) async {
    final s = await open();
    groupRoutes();
    backend.on(
      'POST',
      '/rest/v1/rpc/ask_to_join',
      (r) => http.Response(
        '"ok"',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await showGroups(tester, s);

    await tester.tap(find.text('Join with a group code'));
    await tester.pumpAndSettle();
    expect(inDialog('Group code'), findsOneWidget);
    expect(inDialog('Like GRP-7KQ2'), findsOneWidget);
    // A pasted share message fills the code, in capitals.
    await tester.enterText(
      find.byType(TextField),
      'Join my Koban group Lunch. In Koban, open Groups, tap Join with a group code, and type grp-7kq2. No Koban yet?',
    );
    await tester.pump();
    expect(find.textContaining(' of 8'), findsNothing);
    await tester.tap(inDialog('Ask to join'));
    await tester.pumpAndSettle();

    final asked = backend.requests.singleWhere(
      (r) => r.url.path == '/rest/v1/rpc/ask_to_join',
    );
    expect(jsonDecode(asked.body), {'p_code': 'GRP-7KQ2'});
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(
          'Request sent. You join when the group owner approves it.',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'a failed join opens the dialog again with the typed code, and a second try closes it',
    (tester) async {
      final s = await open();
      groupRoutes();
      String answer = '"unknown"';
      backend.on(
        'POST',
        '/rest/v1/rpc/ask_to_join',
        (r) => http.Response(
          answer,
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await showGroups(tester, s);

      await tester.tap(find.text('Join with a group code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'GRP-7KQ2');
      await tester.pump();
      await tester.tap(inDialog('Ask to join'));
      await tester.pumpAndSettle();

      expect(
        inDialog(
          'No group has this code. Check it with the person who sent it.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(inDialog('Join a group'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'GRP-7KQ2',
      );

      answer = '"ok"';
      await tester.tap(inDialog('Ask to join'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        [
          for (final r in backend.requests)
            if (r.url.path == '/rest/v1/rpc/ask_to_join') jsonDecode(r.body),
        ],
        [
          {'p_code': 'GRP-7KQ2'},
          {'p_code': 'GRP-7KQ2'},
        ],
      );
    },
  );

  testWidgets('two failed pull-downs show the message two times', (
    tester,
  ) async {
    final s = await open();
    groupRoutes();
    await showGroups(tester, s, tall: false);
    expect(find.text('Makan Group'), findsOneWidget);
    backend.on(
      'GET',
      '/rest/v1/groups',
      (r) => jsonReply({'code': 'XX000', 'message': 'internal'}, 500),
    );
    final problem = find.descendant(
      of: find.byType(SnackBar),
      matching: find.text("Koban's server had a problem. Try again later."),
    );

    for (var i = 0; i < 2; i++) {
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(problem, findsOneWidget, reason: 'pull-down ${i + 1}');
      // The snackbar closes.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(problem, findsNothing);
    }
  });

  testWidgets('a removed notice goes away after OK', (tester) async {
    final s = await open();
    groupRoutes();
    backend.on('DELETE', '/rest/v1/removed_notices', empty);
    await showGroups(tester, s);

    const notice = 'The owner removed you from Kedai Group.';
    expect(find.text(notice), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: find.text(notice), matching: find.byType(Row)),
        matching: find.text('OK'),
      ),
    );
    await tester.pumpAndSettle();

    final deleted = backend.requests.singleWhere(
      (r) => r.method == 'DELETE' && r.url.path == '/rest/v1/removed_notices',
    );
    expect(deleted.url.queryParameters['id'], 'eq.7');
    expect(find.text(notice), findsNothing);
  });

  testWidgets('Sign out asks first and keeps the groups on Cancel', (
    tester,
  ) async {
    final s = await open();
    groupRoutes();
    backend.on('POST', '/auth/v1/logout', empty);
    await showGroups(tester, s);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(inDialog('Sign out?'), findsOneWidget);
    expect(
      inDialog('Your groups come back when you sign in again.'),
      findsOneWidget,
    );
    // Only Remove, Leave group and Delete account are red.
    final confirm = tester.widget<TextButton>(
      find.ancestor(
        of: inDialog('Sign out'),
        matching: find.byType(TextButton),
      ),
    );
    expect(confirm.style?.foregroundColor, null);
    await tester.tap(inDialog('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Makan Group'), findsOneWidget);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(inDialog('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Compare spending with friends'), findsOneWidget);
  });

  testWidgets(
    'with no invite code the card asks for it before Google sign-in',
    (tester) async {
      final google = FakeGoogleAccounts();
      final s = await open(stored: false, invite: false, google: google);
      await showGroups(tester, s);

      expect(find.text('Sign in with Google'), findsNothing);
      await tester.tap(find.text('Enter invite code'));
      await tester.pumpAndSettle();
      expect(inDialog('Like ABCD-2345'), findsOneWidget);

      backend.on(
        'POST',
        '/functions/v1/register',
        (r) => jsonReply({'error': 'refused'}, 403),
      );
      await tester.enterText(find.byType(TextField), 'abcd-2345');
      await tester.pump();
      await tester.tap(inDialog('Use code'));
      await tester.pumpAndSettle();
      expect(inDialog('Invite code not accepted.'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      backend.on(
        'POST',
        '/functions/v1/register',
        (r) => jsonReply({'deviceToken': 'tok-1'}),
      );
      await tester.tap(inDialog('Use code'));
      await tester.pumpAndSettle();

      final sentCodes = [
        for (final r in backend.requests)
          if (r.url.path == '/functions/v1/register') jsonDecode(r.body),
      ];
      expect(sentCodes, [
        {'inviteCode': 'ABCD-2345'},
        {'inviteCode': 'ABCD-2345'},
      ]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(s.online.secrets.deviceToken.value, 'tok-1');
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(google.calls, 0);
    },
  );

  testWidgets('the name step waits while another page covers the tab', (
    tester,
  ) async {
    final google = GatedGoogleAccounts();
    final s = await open(stored: false, google: google);
    groupRoutes();
    var profileReads = 0;
    backend.on('GET', '/rest/v1/profiles', (r) {
      profileReads++;
      return jsonReply(
        profileReads == 1
            ? []
            : [
                {'alias': 'Ali'},
              ],
      );
    });
    backend.on('POST', '/rest/v1/rpc/link_account', (r) => jsonReply('ok'));
    await showGroups(tester, s);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    final navigator = Navigator.of(tester.element(find.byType(GroupsScreen)));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('over')),
      ),
    );
    await tester.pumpAndSettle();
    google.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(s.online.groups.state.value.namePending, true);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(inDialog('Your name in groups'), findsOneWidget);
  });

  testWidgets('the first sign-in asks for the name in groups', (tester) async {
    final s = await open(stored: false);
    groupRoutes();
    var profileReads = 0;
    backend.on('GET', '/rest/v1/profiles', (r) {
      // No profile before link_account, one after it.
      profileReads++;
      return jsonReply(
        profileReads == 1
            ? []
            : [
                {'alias': 'Ali'},
              ],
      );
    });
    backend.on('POST', '/rest/v1/rpc/link_account', (r) => jsonReply('ok'));
    await showGroups(tester, s);

    await tester.tap(find.text('Sign in with Google'));
    await tester.pumpAndSettle();

    expect(inDialog('Your name in groups'), findsOneWidget);
    expect(inDialog('Members see this name.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Ali'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Ayu');
    await tester.tap(inDialog('Save'));
    await tester.pumpAndSettle();

    expect(
      [
        for (final r in backend.requests)
          if (r.method == 'PATCH' && r.url.path == '/rest/v1/profiles')
            jsonDecode(r.body) as Map<String, dynamic>,
      ].where((m) => m.containsKey('alias')).single,
      {'alias': 'Ayu'},
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(s.online.groups.state.value.namePending, false);
  });

  // Review Focus 5
  testWidgets('Delete account asks first and then shows the sign-in page', (
    tester,
  ) async {
    final s = await open();
    groupRoutes();
    backend.on('POST', '/functions/v1/delete-account', empty);
    backend.on('POST', '/auth/v1/logout', empty);
    await showGroups(tester, s);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Change your name'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(inDialog('Delete your account?'), findsOneWidget);
    expect(
      inDialog(
        "This removes you from all your groups and deletes your shared totals from Koban's server. The payments on this phone stay.",
      ),
      findsOneWidget,
    );
    expect(
      backend.requests.where((r) => r.url.path.startsWith('/functions')),
      isEmpty,
    );

    // Delete account is red.
    final deleteButton = tester.widget<TextButton>(
      find.ancestor(
        of: inDialog('Delete account'),
        matching: find.byType(TextButton),
      ),
    );
    expect(
      deleteButton.style!.foregroundColor!.resolve({}),
      Theme.of(tester.element(find.byType(AlertDialog))).colorScheme.error,
    );

    await tester.tap(inDialog('Delete account'));
    await tester.tap(inDialog('Delete account'));
    // The functions client encodes the body in its JSON isolate, which runs on real time (5 s at most).
    final signedOut = find.text('Compare spending with friends');
    for (var i = 0; i < 250 && signedOut.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(
      calls().where((c) => c == 'POST /functions/v1/delete-account'),
      hasLength(1),
    );
    expect(find.text('Compare spending with friends'), findsOneWidget);
    expect(find.byTooltip('Account'), findsNothing);
    expect(await s.online.secrets.groupSession(), isNull);
  });

  testWidgets(
    'a failed Delete account asks again, and a later success shows the sign-in page',
    (tester) async {
      final s = await open();
      groupRoutes();
      var deletes = 0;
      backend.on('POST', '/functions/v1/delete-account', (r) {
        deletes++;
        return deletes == 1
            ? jsonReply({'error': 'internal'}, 500)
            : http.Response('', 200);
      });
      backend.on('POST', '/auth/v1/logout', empty);
      await showGroups(tester, s);

      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(inDialog('Delete account'));
      // The functions client encodes the body in its JSON isolate, which runs on real time.
      final problem = find.descendant(
        of: find.byType(SnackBar),
        matching: find.text("Koban's server had a problem. Try again later."),
      );
      for (var i = 0; i < 250 && problem.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(deletes, 1);
      expect(inDialog('Delete your account?'), findsOneWidget);
      expect(find.text('Compare spending with friends'), findsNothing);

      await tester.tap(inDialog('Delete account'));
      final signedOut = find.text('Compare spending with friends');
      for (var i = 0; i < 250 && signedOut.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(deletes, 2);
      expect(inDialog('Delete your account?'), findsNothing);
      expect(signedOut, findsOneWidget);
      expect(await s.online.secrets.groupSession(), isNull);
    },
  );

  testWidgets(
    'Groups meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      final s = await open();
      groupRoutes();
      await showGroups(tester, s, textScale: 1.3);

      expect(tester.takeException(), null);
      expect(find.text('Makan Group'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  test('a second run while the first runs makes no repository call', () async {
    final s = await testServices();
    addTearDown(() => s.online.dispose());
    final vm = GroupsViewModel(s);
    addTearDown(vm.dispose);
    final gate = Completer<String?>();
    var calls = 0;
    Future<String?> action(GroupRepository r) {
      calls++;
      return gate.future;
    }

    final first = vm.run(action);
    final second = vm.run(action);
    expect((calls, vm.busy), (1, true));

    gate.complete(null);
    await Future.wait([first, second]);
    expect((calls, vm.busy), (1, false));
  });
}
