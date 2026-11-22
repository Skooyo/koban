import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:koban/app/app_services.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/screens/groups/group_screen.dart';
import 'package:koban/theme/mon.dart';
import 'package:material_ui/material_ui.dart';

import '../online/group_repository_test.dart'
    show FakeGoogleAccounts, empty, jsonReply;
import '../online/group_session_test.dart' show storedSession, tokenReply;
import '../support/fake_backend.dart';
import '../support/harness.dart';

void main() {
  late FakeBackend backend;
  late FakeChannel device;

  /// The group list that the server gives. A test can change it.
  var groups = <Map<String, Object?>>[];

  Map<String, Object?> makan() => {
    'id': 'g1',
    'name': 'Makan Group',
    'code': 'GRP-7KQ2',
    'owner_id': 'user-1',
    'group_members': [
      {'user_id': 'user-1'},
      {'user_id': 'user-2'},
      {'user_id': 'user-3'},
    ],
  };

  Future<AppServices> open() async {
    backend = FakeBackend();
    groups = [makan()];
    device = FakeChannel(deviceChannelName, {
      'relativeTime': '2 days ago',
      'shareText': null,
    });
    backend.on('POST', '/auth/v1/token', tokenReply);
    final s = await testServices(
      now: DateTime.utc(2026, 11, 13, 4),
      http: backend.client,
      google: FakeGoogleAccounts(),
      device: device,
      secrets: {
        'device_token': 'test-device-token',
        'group_session': storedSession,
      },
    );
    addTearDown(() => s.online.groups.dispose());
    return s;
  }

  /// The routes of a refresh, of the sync and of the group page.
  void routes({bool request = true}) {
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
        if (request)
          {
            'group_id': 'g1',
            'user_id': 'user-4',
            'profiles': {'alias': 'Siti'},
          },
      ]),
    );
    backend.on('GET', '/rest/v1/groups', (r) => jsonReply(groups));
    backend.on('GET', '/rest/v1/removed_notices', (r) => jsonReply([]));
    // One answer for the sync read and for the member read of the group page.
    backend.on(
      'GET',
      '/rest/v1/group_members',
      (r) => jsonReply([
        {
          'user_id': 'user-1',
          'joined_at': '2026-11-10T01:00:00+00:00',
          'profiles': {
            'alias': 'Ali',
            'totals_updated_at': '2026-11-13T03:00:00+00:00',
          },
        },
        {
          'user_id': 'user-2',
          'joined_at': '2026-11-10T02:00:00+00:00',
          'profiles': {
            'alias': 'Mei',
            'totals_updated_at': '2026-11-11T04:00:00+00:00',
          },
        },
        {
          'user_id': 'user-3',
          'joined_at': '2026-11-10T03:00:00+00:00',
          'profiles': {'alias': 'Abu', 'totals_updated_at': null},
        },
      ]),
    );
    backend.on('GET', '/rest/v1/shared_totals', (r) {
      final week = r.url.queryParameters['period'] == 'eq.week';
      return jsonReply([
        {'user_id': 'user-1', 'category': 'Food & Dining', 'amount': 20},
        {'user_id': 'user-1', 'category': 'Coffee Club', 'amount': 10},
        {'user_id': 'user-2', 'category': 'Transport', 'amount': 45.5},
        if (week) {'user_id': 'user-1', 'category': 'Health', 'amount': 5},
      ]);
    });
    backend.on('DELETE', '/rest/v1/shared_totals', empty);
    backend.on('PATCH', '/rest/v1/profiles', empty);
  }

  /// Starts the app, opens the Groups tab, then the group Makan Group.
  Future<void> openGroup(
    WidgetTester tester,
    AppServices s, {
    double textScale = 1,
  }) async {
    // A tall screen: the list builds all its rows.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpKoban(tester, s, textScale: textScale);
    HomeShell.of(tester.element(find.byType(IndexedStack)))
        .select(KobanTab.groups);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makan Group'));
    await tester.pumpAndSettle();
  }

  Finder onPage(Finder f) =>
      find.descendant(of: find.byType(GroupScreen), matching: f);
  Finder onPageText(String t) => onPage(find.text(t));
  Finder inDialog(String t) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(t));

  List<http.Request> sent(String path) =>
      backend.requests.where((r) => r.url.path == path).toList();

  testWidgets('my card shows my total, my place and the days left', (
    tester,
  ) async {
    final s = await open();
    routes();
    await openGroup(tester, s);

    expect(onPageText('Makan Group'), findsOneWidget);
    expect(
      onPageText('Updated just now. Pull down to refresh.'),
      findsOneWidget,
    );
    expect(onPageText('You spent in November'), findsOneWidget);
    expect(onPageText('RM 30.00'), findsWidgets);
    expect(
      onPageText('2nd of 3 in Makan Group. Resets in 18 days.'),
      findsOneWidget,
    );
    expect(
      sent('/rest/v1/shared_totals').last.url.queryParameters['period_start'],
      'eq.2026-11-01',
    );
  });

  testWidgets('the week view resets on Monday', (tester) async {
    final s = await open();
    routes();
    await openGroup(tester, s);

    await tester.tap(onPageText('Week'));
    await tester.pumpAndSettle();

    expect(onPageText('You spent this week'), findsOneWidget);
    expect(onPageText('RM 35.00'), findsWidgets);
    expect(
      onPageText('2nd of 3 in Makan Group. Resets in 3 days.'),
      findsOneWidget,
    );
    final q = sent('/rest/v1/shared_totals').last.url.queryParameters;
    expect(q['period'], 'eq.week');
    expect(q['period_start'], 'eq.2026-11-09');
  });

  testWidgets(
    'members are listed by total with stale and missing totals marked',
    (tester) async {
      final s = await open();
      routes();
      await openGroup(tester, s);

      final ys = [
        for (final n in ['Mei', 'Ali (you)', 'Abu'])
          tester.getTopLeft(onPageText(n)).dy,
      ];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(onPageText('Updated 2 days ago'), findsOneWidget);
      expect(onPageText('No totals sent yet'), findsOneWidget);
      // Ali sent totals 1 hour ago: no stale line for Ali.
      expect(find.textContaining('Updated 2 days ago'), findsOneWidget);
      expect(
        device.calls.firstWhere((c) => c.method == 'relativeTime').arguments,
        {
          'time': DateTime.utc(2026, 11, 11, 4).millisecondsSinceEpoch,
          'now': DateTime.utc(2026, 11, 13, 4).millisecondsSinceEpoch,
        },
      );
    },
  );

  testWidgets(
    'a member row opens its categories and the owner can remove the member',
    (tester) async {
      final s = await open();
      routes();
      backend.on('POST', '/rest/v1/rpc/remove_member', (r) => jsonReply('ok'));
      await openGroup(tester, s);
      // The category chip is the only Transport until a row opens.
      expect(onPageText('Transport'), findsOneWidget);
      expect(onPageText('Remove'), findsNothing);

      await tester.tap(onPageText('Mei'));
      await tester.pumpAndSettle();
      expect(onPageText('Transport'), findsNWidgets(2));
      expect(onPageText('Make owner'), findsOneWidget);

      // Abu has no totals. One row is open at a time.
      await tester.tap(onPageText('Abu'));
      await tester.pumpAndSettle();
      expect(onPageText('No spending in this period.'), findsOneWidget);
      expect(onPageText('Transport'), findsOneWidget);

      await tester.tap(onPageText('Mei'));
      await tester.pumpAndSettle();
      await tester.tap(onPageText('Remove'));
      await tester.pumpAndSettle();
      expect(inDialog('Remove Mei?'), findsOneWidget);
      expect(
        inDialog(
          "Mei stops seeing this group, and the members stop seeing Mei's totals.",
        ),
        findsOneWidget,
      );
      // Two fast taps send one request.
      await tester.tap(inDialog('Remove'));
      await tester.tap(inDialog('Remove'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final req = sent('/rest/v1/rpc/remove_member').single;
      expect(jsonDecode(req.body), {'p_group': 'g1', 'p_user': 'user-2'});
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('a failed rename opens the dialog again with the typed name', (
    tester,
  ) async {
    final s = await open();
    routes();
    var answer = 'not_owner';
    backend.on('POST', '/rest/v1/rpc/rename_group', (r) => jsonReply(answer));
    await openGroup(tester, s);

    await tester.tap(find.byTooltip('Group actions'));
    await tester.pumpAndSettle();
    expect(find.text('Make a new code'), findsOneWidget);
    await tester.tap(find.text('Rename group'));
    await tester.pumpAndSettle();
    expect(inDialog('Rename group'), findsOneWidget);
    expect(inDialog('11 of 40'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Lunch Club');
    await tester.pump();
    await tester.tap(inDialog('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Only the group owner can do this.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Lunch Club'), findsOneWidget);

    answer = 'ok';
    await tester.tap(inDialog('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(sent('/rest/v1/rpc/rename_group').map((r) => jsonDecode(r.body)), [
      {'p_group': 'g1', 'p_name': 'Lunch Club'},
      {'p_group': 'g1', 'p_name': 'Lunch Club'},
    ]);
  });

  testWidgets('Share code sends the 0.1.1 text', (tester) async {
    final s = await open();
    routes();
    await openGroup(tester, s);

    expect(onPageText('Group code'), findsOneWidget);
    expect(onPageText('GRP-7KQ2'), findsOneWidget);
    await tester.ensureVisible(onPageText('Share code'));
    await tester.tap(onPageText('Share code'));
    await tester.pumpAndSettle();

    expect(device.calls.singleWhere((c) => c.method == 'shareText').arguments, {
      'text': 'Join my Koban group "Makan Group" with the code GRP-7KQ2.',
      'chooserTitle': 'Share group code',
    });
  });

  testWidgets('Approve answers the request and reloads', (tester) async {
    final s = await open();
    routes();
    backend.on('POST', '/rest/v1/rpc/answer_request', (r) => jsonReply('ok'));
    await openGroup(tester, s);

    expect(onPageText('Join requests'), findsOneWidget);
    expect(
      onPageText(
        'Only you see these, because you own the group. Requests end after 7 days.',
      ),
      findsOneWidget,
    );
    expect(onPageText('Siti'), findsOneWidget);
    expect(onPageText('Decline'), findsOneWidget);
    // After the answer the server has no request.
    routes(request: false);
    final before = sent('/rest/v1/group_members').length;
    await tester.tap(onPageText('Approve'));
    await tester.pumpAndSettle();

    expect(jsonDecode(sent('/rest/v1/rpc/answer_request').single.body), {
      'p_group': 'g1',
      'p_user': 'user-4',
      'p_approve': true,
    });
    expect(sent('/rest/v1/group_members').length, greaterThan(before));
    expect(onPageText('Join requests'), findsNothing);
  });

  testWidgets('leaving the group closes the page', (tester) async {
    final s = await open();
    routes();
    backend.on('POST', '/rest/v1/rpc/leave_group', (r) => jsonReply('ok'));
    await openGroup(tester, s);

    await tester.tap(find.byTooltip('Group actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave group'));
    await tester.pumpAndSettle();
    expect(inDialog('Leave Makan Group?'), findsOneWidget);
    expect(
      inDialog(
        'Members stop seeing your totals. To come back, ask the owner again with the group code.',
      ),
      findsOneWidget,
    );
    groups = [];
    await tester.tap(inDialog('Leave group'));
    await tester.pumpAndSettle();

    expect(find.byType(GroupScreen), findsNothing);
    expect(find.text('Groups'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refresh error shows one time with the tab and the page', (
    tester,
  ) async {
    final s = await open();
    routes();
    await openGroup(tester, s);

    backend.on(
      'GET',
      '/rest/v1/groups',
      (r) => http.Response(
        '{}',
        500,
        headers: {'content-type': 'application/json'},
      ),
    );
    // The tall screen needs a long pull.
    await tester.fling(onPageText('Members'), const Offset(0, 1500), 1000);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);

    // A second copy would show after the first one closes.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  test('ordinal suffixes follow English', () {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 101, 111].map(ordinal), [
      '1st',
      '2nd',
      '3rd',
      '4th',
      '11th',
      '12th',
      '13th',
      '21st',
      '22nd',
      '101st',
      '111th',
    ]);
  });

  testWidgets(
    'the group page meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      final s = await open();
      routes();
      await openGroup(tester, s, textScale: 1.3);
      await tester.tap(onPageText('Mei'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('How to read this list'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Hide how to read this list'), findsOneWidget);
      expect(
        onPageText(
          'Members are listed by total spending. A higher total is not a win. Tap a member to see their categories, in their own names.',
        ),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );

  testWidgets('a group that fails to load shows Mon and Try again retries', (
    tester,
  ) async {
    final s = await open();
    routes();
    var down = true;
    backend.on('GET', '/rest/v1/shared_totals', (r) {
      if (down) return http.Response('{"message":"boom"}', 500);
      return jsonReply([
        {'user_id': 'user-1', 'category': 'Food & Dining', 'amount': 20},
      ]);
    });
    await openGroup(tester, s);

    expect(onPageText('Could not load the group.'), findsOneWidget);
    expect(
      onPageText('Check the internet connection, then try again.'),
      findsOneWidget,
    );
    expect(onPage(find.byType(Mon)), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    down = false;
    await tester.tap(onPageText('Try again'));
    await tester.pumpAndSettle();
    expect(onPageText('Could not load the group.'), findsNothing);
    expect(onPageText('You spent in November'), findsOneWidget);
  });
}
