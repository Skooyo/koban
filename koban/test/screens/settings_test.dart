import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/capture/listener_control.dart';
import 'package:koban/data/database.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/settings/settings_screen.dart';
import 'package:koban/screens/settings/settings_view_model.dart';
import 'package:koban/ui/kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/harness.dart';

const maybank = 'com.maybank2u.life';
const tng = 'my.com.tngdigital.ewallet';
const sample =
    'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.';
const reconnectHint =
    ' If an alert appears, tap it or open notification access settings.';
const accepted = "Accepted. Receipts are read by Claude on Koban's server.";

Map<String, Object?> logRow(String id) => {
  'id': id,
  'packageName': maybank,
  'title': 'Maybank',
  'body': sample,
  'postTime': 1761999940000,
  'capturedAt': 1761999940500,
  'event': 'POSTED',
  'disposition': 'WAITING',
  'detail': 'RESTORAN CONTOH · RM 15.00',
};

/// A listener channel with the answers of a phone with access and a connected listener.
FakeChannel listenerChannel({
  bool xiaomi = false,
  String reconnect = 'ATTEMPTED',
  bool connected = true,
}) => FakeChannel(ListenerControl.channelName, {
  'isAccessGranted': true,
  'isConnected': connected,
  'isBatteryOptimizationIgnored': false,
  'isXiaomiFamily': xiaomi,
  'recentNotifications': [logRow('a'), logRow('b')],
  'reconnect': reconnect,
  'openBackgroundSettings': 'XIAOMI_AUTOSTART',
});

FakeChannel deviceChannel() =>
    FakeChannel(deviceChannelName, {'versionName': '0.1.1'});

Future<AppServices> settingsServices({
  FakeChannel? listener,
  Map<String, Object> prefs = const {},
  Map<String, Object> secrets = const {},
  http.Client? http,
}) => testServices(
  http: http,
  listener: listener ?? listenerChannel(),
  device: deviceChannel(),
  prefs: prefs,
  secrets: secrets,
);

Future<void> pumpSettings(
  WidgetTester tester,
  AppServices s, {
  double textScale = 1,
  Duration reconnectWait = const Duration(seconds: 1),
}) async {
  // A tall screen, so the lazy list builds every row.
  tester.view.physicalSize = const Size(411, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpKoban(
    tester,
    s,
    home: SettingsScreen(reconnectWait: reconnectWait),
    textScale: textScale,
  );
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextField, label);

/// Opens the Settings section that has this row title.
Future<void> openSection(WidgetTester tester, String title) async {
  await tester.tap(find.widgetWithText(KobanRow, title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings is a short list and says that tracking is on', (
    tester,
  ) async {
    final s = await settingsServices(
      prefs: {
        'payment_apps_chosen': true,
        'payment_app_allowlist': [maybank, tng],
      },
    );
    await pumpSettings(tester, s);
    double top(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('On · 2 apps chosen'), findsOneWidget);
    expect(find.text('Tracking is off'), findsNothing);
    expect(find.text('Off · Koban cannot read notifications'), findsNothing);
    expect(find.text('7 categories · 0 monthly limits'), findsOneWidget);
    expect(find.text('Koban 0.1.1'), findsOneWidget);
    // Categories and budgets is the second section.
    expect(top('Categories and budgets'), greaterThan(top('Tracking')));
    expect(top('Online features'), greaterThan(top('Categories and budgets')));
    expect(top('Troubleshooting'), greaterThan(top('Check for updates')));
    expect(find.text('Notification log'), findsNothing);
    expect(find.text('Parser test tool'), findsNothing);
  });

  testWidgets('Settings says when tracking is off', (tester) async {
    final listener = listenerChannel();
    listener.answers['isAccessGranted'] = false;
    await pumpSettings(tester, await settingsServices(listener: listener));
    expect(find.text('Off · Koban cannot read notifications'), findsOneWidget);
    await openSection(tester, 'Tracking');
    expect(find.text('Tracking is off'), findsOneWidget);
  });

  testWidgets('Tracking holds the apps and the battery row', (tester) async {
    final listener = listenerChannel();
    await pumpSettings(tester, await settingsServices(listener: listener));
    await openSection(tester, 'Tracking');
    expect(find.text('Tracking is off'), findsNothing);
    expect(listener.calls.map((c) => c.method), contains('ensureActive'));
    await tester.tap(
      find.text('On. Tracking may stop in the background. Tap to turn it off.'),
    );
    await tester.pump();
    expect(
      listener.calls.map((c) => c.method),
      contains('openBatteryOptimizationSettings'),
    );
  });

  testWidgets('Troubleshooting holds the log, the restart and the test', (
    tester,
  ) async {
    final listener = listenerChannel();
    listener.answers['recentNotifications'] = [logRow('a')];
    await pumpSettings(tester, await settingsServices(listener: listener));
    await openSection(tester, 'Troubleshooting');
    double top(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(find.text('1 notification captured'), findsOneWidget);
    expect(find.text('Reconnect listener'), findsNothing);
    expect(find.byIcon(Icons.bug_report), findsNothing);
    expect(
      find.descendant(
        of: find.widgetWithText(KobanRow, 'Notification log'),
        matching: find.byIcon(Icons.list),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Use this when new payments stop showing up in Koban.'),
      findsOneWidget,
    );
    expect(
      top('Restart payment tracking'),
      greaterThan(top('Notification log')),
    );
    expect(
      top('Test a notification'),
      greaterThan(top('Restart payment tracking')),
    );
  });

  testWidgets('the Payment apps row says when no app is chosen', (
    tester,
  ) async {
    final s = await settingsServices(prefs: {'payment_apps_chosen': true});
    await pumpSettings(tester, s);
    await openSection(tester, 'Tracking');
    expect(find.text('None chosen. Koban listens to no app.'), findsOneWidget);
    await s.paymentApps.save({maybank});
    await s.settings.reload();
    await tester.pumpAndSettle();
    expect(find.text('1 app chosen'), findsOneWidget);
  });

  testWidgets(
    'reconnect shows Reconnecting and then the result after the wait',
    (tester) async {
      await pumpSettings(tester, await settingsServices());
      await openSection(tester, 'Troubleshooting');
      await tester.tap(find.text('Restart payment tracking'));
      await tester.pump();
      expect(find.text('Reconnecting…$reconnectHint'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Reconnecting…$reconnectHint'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('Tracking is connected.$reconnectHint'), findsOneWidget);
    },
  );

  testWidgets('a reconnect with a listener that stays down says so', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      await settingsServices(listener: listenerChannel(connected: false)),
    );
    await openSection(tester, 'Troubleshooting');
    await tester.tap(find.text('Restart payment tracking'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      find.text(
        'Still disconnected after 60 s — tap the notification or open notification access settings.$reconnectHint',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a second Reconnect tap while one waits starts no second timer', (
    tester,
  ) async {
    final listener = listenerChannel();
    await pumpSettings(tester, await settingsServices(listener: listener));
    await openSection(tester, 'Troubleshooting');
    int reconnects() =>
        listener.calls.where((c) => c.method == 'reconnect').length;
    await tester.tap(find.text('Restart payment tracking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Restart payment tracking'));
    await tester.pump();
    expect(reconnects(), 1);
    // The result shows 1 s after the first tap, not after the second.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Tracking is connected.$reconnectHint'), findsOneWidget);
    // The next tap works again.
    await tester.tap(find.text('Restart payment tracking'));
    await tester.pump();
    expect(find.text('Reconnecting…$reconnectHint'), findsOneWidget);
    expect(reconnects(), 2);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  });

  testWidgets('a throttled reconnect says to wait', (tester) async {
    await pumpSettings(
      tester,
      await settingsServices(listener: listenerChannel(reconnect: 'THROTTLED')),
    );
    await openSection(tester, 'Troubleshooting');
    await tester.tap(find.text('Restart payment tracking'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text(
        'Reconnect already attempted recently — wait a moment and try again.$reconnectHint',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the dark mode switch changes the theme at once', (tester) async {
    await pumpSettings(tester, await settingsServices());
    Brightness brightness() =>
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness;
    expect(brightness(), Brightness.light);
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(await SharedPreferencesAsync().getBool('dark_mode'), true);
  });

  testWidgets('own categories can be added and deleted, built-in ones cannot', (
    tester,
  ) async {
    await pumpSettings(tester, await settingsServices());
    await openSection(tester, 'Categories and budgets');
    expect(find.text('Food & Dining'), findsOneWidget);
    expect(find.text('Your own'), findsNothing);
    expect(find.byTooltip('Delete category Food & Dining'), findsNothing);
    final add = find.widgetWithText(FilledButton, 'Add');
    expect(tester.widget<FilledButton>(add).onPressed, isNull);
    await tester.enterText(field('New category'), 'Gym');
    await tester.pump();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Gym added'), findsOneWidget);
    expect(find.text('Your own'), findsOneWidget);
    expect(
      tester.widget<TextField>(field('New category')).controller!.text,
      '',
    );
    await tester.tap(find.byTooltip('Delete category Gym'));
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsNothing);
    expect(find.text('Gym deleted.'), findsOneWidget);
  });

  testWidgets('the Done key adds a category and a used name is refused', (
    tester,
  ) async {
    await pumpSettings(tester, await settingsServices());
    await openSection(tester, 'Categories and budgets');
    await tester.enterText(field('New category'), 'Gym');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Gym added'), findsOneWidget);
    await tester.enterText(field('New category'), 'gym');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('You have a category called Gym'), findsOneWidget);
    expect(find.text('Gym'), findsOneWidget);
    await tester.enterText(field('New category'), 'gym2');
    await tester.pump();
    expect(find.text('You have a category called Gym'), findsNothing);
  });

  testWidgets(
    'deleting a category says how many payments become Uncategorized',
    (tester) async {
      final s = await settingsServices();
      await s.categories.addCategory('Gym', '#5C6BC0');
      final gym = (await s.categories.getAll()).singleWhere(
        (c) => c.name == 'Gym',
      );
      for (var i = 0; i < 4; i++) {
        await s.db
            .into(s.db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'e$i',
                amount: Decimal.parse('5.00'),
                currency: 'MYR',
                rawNotificationText: 'raw',
                sourcePackage: 'pkg',
                notificationPostTime: 1761999940000,
                createdAt: 0,
                dedupKey: 'k$i',
                status: ExpenseStatus.autoSaved,
                confidence: ParseConfidence.high,
                transactionType: TransactionType.withdraw,
                privateToGroups: false,
                categoryId: Value(gym.id),
              ),
            );
      }
      await pumpSettings(tester, s);
      await openSection(tester, 'Categories and budgets');
      await tester.tap(find.byTooltip('Delete category Gym'));
      await tester.pumpAndSettle();
      expect(
        find.text('Gym deleted. 4 payments are now Uncategorized.'),
        findsOneWidget,
      );
      expect(find.text('Undo'), findsOneWidget);
    },
  );

  testWidgets('a monthly limit is set, changed and cleared', (tester) async {
    final s = await settingsServices();
    await pumpSettings(tester, s);
    await openSection(tester, 'Categories and budgets');
    final food = find.byKey(const ValueKey('limit-food'));
    Finder box() => find.descendant(of: food, matching: find.byType(TextField));
    expect(find.text('RM '), findsNWidgets(7));
    await tester.tap(box());
    await tester.enterText(box(), '500');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(box()).controller!.text, '500.00');
    expect(
      (await s.budgets.getMonth()).items.single.limit,
      Decimal.parse('500'),
    );
    expect(find.text('7 categories · 1 monthly limit'), findsNothing);

    // Zero is not a limit. The old one comes back.
    await tester.tap(box());
    await tester.enterText(box(), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(box()).controller!.text, '500.00');

    await tester.tap(box());
    await tester.enterText(box(), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await s.budgets.getMonth()).isEmpty, true);
    expect(tester.widget<TextField>(box()).controller!.text, '');
  });

  testWidgets('a failed limit save says so and the field keeps the old limit', (
    tester,
  ) async {
    final s = await settingsServices();
    await s.budgets.setLimit('food', Decimal.parse('300'));
    await pumpSettings(tester, s);
    await openSection(tester, 'Categories and budgets');
    final box = find.descendant(
      of: find.byKey(const ValueKey('limit-food')),
      matching: find.byType(TextField),
    );
    await s.db.customStatement('DROP TABLE budget_limits');
    await tester.tap(box);
    await tester.enterText(box, '500');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Could not save the limit. Try again.'), findsOneWidget);
    expect(tester.widget<TextField>(box).controller!.text, '300.00');
  });

  testWidgets('a typed limit is saved when the app goes to the background', (
    tester,
  ) async {
    final s = await settingsServices();
    await pumpSettings(tester, s);
    await openSection(tester, 'Categories and budgets');
    final box = find.descendant(
      of: find.byKey(const ValueKey('limit-food')),
      matching: find.byType(TextField),
    );
    await tester.tap(box);
    await tester.enterText(box, '250');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(
      (await s.budgets.getMonth()).items.single.limit,
      Decimal.parse('250'),
    );
  });

  testWidgets('at text scale 1.3 the limit field goes under the name', (
    tester,
  ) async {
    final s = await settingsServices();
    await pumpSettings(tester, s, textScale: 1.3);
    tester.view.physicalSize = const Size(360, 5000);
    await tester.pumpAndSettle();
    await openSection(tester, 'Categories and budgets');
    final name = find.descendant(
      of: find.byKey(const ValueKey('entertainment')),
      matching: find.text('Entertainment'),
    );
    final field = find.byKey(const ValueKey('limit-entertainment'));
    expect(
      tester.getTopLeft(field).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(name).dy),
    );
    // The field has the row's width, not the 144 dp of the inline layout.
    expect(tester.getSize(field).width, greaterThan(200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a saved limit shows on the field and in the Settings count', (
    tester,
  ) async {
    final s = await settingsServices();
    await s.budgets.setLimit('transport', Decimal.parse('300'));
    await pumpSettings(tester, s);
    expect(find.text('7 categories · 1 monthly limit'), findsOneWidget);
    await openSection(tester, 'Categories and budgets');
    final box = find.descendant(
      of: find.byKey(const ValueKey('limit-transport')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(box).controller!.text, '300.00');
  });

  testWidgets('the notification test reads a sample text', (tester) async {
    await pumpSettings(tester, await settingsServices());
    await openSection(tester, 'Troubleshooting');
    await tester.enterText(field('Notification text'), sample);
    await tester.tap(find.text('Test notification'));
    await tester.pumpAndSettle();
    expect(
      find.text('Amount: RM 15.00\nShop: RESTORAN CONTOH\nKind: Spent'),
      findsOneWidget,
    );
    await tester.enterText(field('Notification text'), 'Hello');
    await tester.tap(find.text('Test notification'));
    await tester.pumpAndSettle();
    expect(find.text('No rule matched this text'), findsOneWidget);
  });

  testWidgets('Use code checks the code and then shows Accepted', (
    tester,
  ) async {
    final gate = Completer<http.Response>();
    final seen = <http.Request>[];
    final s = await testServices(
      listener: listenerChannel(),
      device: deviceChannel(),
      http: MockClient((r) {
        seen.add(r);
        return gate.future;
      }),
    );
    await pumpSettings(tester, s);
    await openSection(tester, 'Online features');
    final use = find.widgetWithText(FilledButton, 'Use code');
    expect(tester.widget<FilledButton>(use).onPressed, isNull);
    await tester.enterText(field('XXXX-XXXX'), 'k7qx-m2pa');
    await tester.pump();
    expect(
      tester.widget<TextField>(field('XXXX-XXXX')).controller!.text,
      'K7QX-M2PA',
    );

    await tester.tap(use);
    await tester.pump();
    final busy = find.widgetWithText(FilledButton, 'Checking…');
    expect(busy, findsOneWidget);
    expect(tester.widget<FilledButton>(busy).onPressed, isNull);
    expect(seen, hasLength(1));

    gate.complete(http.Response('{"deviceToken":"test-device-token"}', 200));
    await tester.pumpAndSettle();
    expect(find.text(accepted), findsOneWidget);
    expect(seen, hasLength(1));
    expect(jsonDecode(seen.single.body), {'inviteCode': 'K7QX-M2PA'});
    expect(s.online.secrets.deviceToken.value, 'test-device-token');
  });

  testWidgets('a refused code shows the message under the field', (
    tester,
  ) async {
    final s = await testServices(
      listener: listenerChannel(),
      device: deviceChannel(),
      http: MockClient((r) async => http.Response('{}', 403)),
    );
    await pumpSettings(tester, s);
    await openSection(tester, 'Online features');
    await tester.enterText(field('XXXX-XXXX'), 'k7qx-m2pa');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Use code'));
    await tester.pumpAndSettle();
    expect(find.text('Invite code not accepted.'), findsOneWidget);
    expect(find.text(accepted), findsNothing);
    expect(s.online.secrets.deviceToken.value, '');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Use code'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a second tap while the check runs sends no second request', (
    tester,
  ) async {
    final gate = Completer<http.Response>();
    var requests = 0;
    final s = await testServices(
      listener: listenerChannel(),
      device: deviceChannel(),
      http: MockClient((r) {
        requests++;
        return gate.future;
      }),
    );
    await pumpSettings(tester, s);
    final vm = SettingsViewModel(s);
    addTearDown(vm.dispose);

    final first = vm.enterInviteCode('K7QX-M2PA');
    final second = vm.enterInviteCode('K7QX-M2PA');
    await tester.pump();
    gate.complete(http.Response('{"deviceToken":"test-device-token"}', 200));
    await Future.wait([first, second]);

    expect(requests, 1);
  });

  testWidgets('a malformed good answer shows the server problem text', (
    tester,
  ) async {
    final s = await testServices(
      listener: listenerChannel(),
      device: deviceChannel(),
      http: MockClient(
        (r) async => http.Response('{"deviceToken":"test-device-tok', 200),
      ),
    );
    await pumpSettings(tester, s);
    await openSection(tester, 'Online features');
    await tester.enterText(field('XXXX-XXXX'), 'k7qx-m2pa');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Use code'));
    await tester.pumpAndSettle();

    expect(
      find.text("Koban's server had a problem. Try again later."),
      findsOneWidget,
    );
    expect(s.online.secrets.deviceToken.value, '');
  });

  testWidgets('Check for updates says up to date when nothing is new', (
    tester,
  ) async {
    final s = await settingsServices(
      http: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'tag_name': 'v0.1.1',
            'body': '',
            'assets': [
              {
                'name': 'koban-6.apk',
                'browser_download_url': 'https://example.test/koban-6.apk',
                'size': 5,
              },
            ],
          }),
          200,
        ),
      ),
    );
    await pumpSettings(tester, s);
    expect(find.text('Koban is up to date.'), findsNothing);
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text('Koban is up to date.'), findsOneWidget);
  });

  testWidgets('a failed manual check shows the message in a dialog', (
    tester,
  ) async {
    final s = await settingsServices(
      http: MockClient((_) async => http.Response('{}', 500)),
    );
    tester.view.physicalSize = const Size(411, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The dialog belongs to the tab shell, so Settings opens from Home.
    await pumpKoban(tester, s);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not check for updates. Try again later.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not check for updates. Try again later.'),
      findsNothing,
    );
  });

  testWidgets('Check for updates is off when Online features is off', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      await settingsServices(prefs: {'online_features': false}),
    );
    expect(find.text('Off'), findsOneWidget);
    expect(
      find.text('Turn on Online features to check for updates.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<KobanRow>(find.widgetWithText(KobanRow, 'Check for updates'))
          .onTap,
      isNull,
    );
    await openSection(tester, 'Online features');
    expect(
      find.text(
        'Off: Koban makes no network calls. Groups and reading receipts with Claude stop.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Online features').last);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'On: groups and reading receipts with Claude can use the internet.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      find.text('Turn on Online features to check for updates.'),
      findsNothing,
    );
  });

  testWidgets('a stored invite code shows Accepted and Remove deletes it', (
    tester,
  ) async {
    final s = await settingsServices(
      secrets: {'device_token': 'test-device-token'},
    );
    await pumpSettings(tester, s);
    expect(find.text('On · invite code accepted'), findsOneWidget);
    await openSection(tester, 'Online features');
    expect(find.text(accepted), findsOneWidget);
    expect(field('XXXX-XXXX'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text(accepted), findsNothing);
    expect(field('XXXX-XXXX'), findsOneWidget);
    expect(s.online.secrets.deviceToken.value, '');
  });

  testWidgets('on a Xiaomi phone the autostart row and the 7 steps show', (
    tester,
  ) async {
    final listener = listenerChannel(xiaomi: true);
    await pumpSettings(tester, await settingsServices(listener: listener));
    await openSection(tester, 'Tracking');
    expect(find.text('Xiaomi autostart'), findsOneWidget);
    expect(
      find.text('• Security app → Autostart → turn ON for Koban'),
      findsOneWidget,
    );
    expect(xiaomiChecklist.length, 7);
    for (final step in xiaomiChecklist) {
      expect(find.text('• $step'), findsOneWidget);
    }
    await tester.tap(find.text('Xiaomi autostart'));
    await tester.pump();
    expect(
      listener.calls.map((c) => c.method),
      contains('openBackgroundSettings'),
    );
  });

  testWidgets(
    'the Home settings button and the Set up later row open Settings',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await settingsServices();
      await pumpKoban(tester, s);
      await tester.pumpAndSettle();
      expect(find.text('Set up later'), findsOneWidget);
      await tester.tap(find.text('Read receipts, join groups'));
      await tester.pumpAndSettle();
      expect(find.text('Dark mode'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Dark mode'), findsNothing);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Dark mode'), findsOneWidget);
    },
  );

  testWidgets(
    'every Settings page meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSettings(
        tester,
        await settingsServices(
          listener: listenerChannel(xiaomi: true),
          prefs: {
            'payment_app_allowlist': [maybank],
          },
        ),
        textScale: 1.3,
      );
      for (final section in [
        null,
        'Tracking',
        'Categories and budgets',
        'Online features',
        'Troubleshooting',
      ]) {
        if (section != null) await openSection(tester, section);
        expect(tester.takeException(), isNull, reason: '$section');
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        if (section != null) {
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
        }
      }
      handle.dispose();
    },
  );
}
