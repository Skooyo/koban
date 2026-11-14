import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/capture/listener_control.dart';
import 'package:koban/screens/settings/settings_screen.dart';
import 'package:koban/screens/settings/settings_view_model.dart';
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
const placeholder = 'Comes with the online features in milestone 5.';

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
}) => testServices(
  listener: listener ?? listenerChannel(),
  device: deviceChannel(),
  prefs: prefs,
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

void main() {
  testWidgets('Settings shows the tracking rows with their counts', (
    tester,
  ) async {
    final listener = listenerChannel();
    final s = await settingsServices(
      listener: listener,
      prefs: {
        'payment_apps_chosen': true,
        'payment_app_allowlist': [maybank, tng],
      },
    );
    await pumpSettings(tester, s);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Tracking on'), findsOneWidget);
    expect(find.text('2 apps chosen'), findsOneWidget);
    expect(find.text('2 notifications captured'), findsOneWidget);
    expect(
      find.text(
        'Use this when payments stop showing up. It retries for about 60 seconds.',
      ),
      findsOneWidget,
    );
    expect(find.text('App version 0.1.1'), findsOneWidget);
    expect(find.text('Xiaomi autostart'), findsNothing);
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

  testWidgets('the Payment apps row says when no app is chosen', (
    tester,
  ) async {
    final s = await settingsServices(prefs: {'payment_apps_chosen': true});
    await pumpSettings(tester, s);
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
      await tester.tap(find.text('Reconnect listener'));
      await tester.pump();
      expect(find.text('Reconnecting…$reconnectHint'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.text('Reconnecting…$reconnectHint'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('Listener connected.$reconnectHint'), findsOneWidget);
    },
  );

  testWidgets('a reconnect with a listener that stays down says so', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      await settingsServices(listener: listenerChannel(connected: false)),
    );
    await tester.tap(find.text('Reconnect listener'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(
      find.text(
        'Still disconnected after 60s — tap the alert notification or open notification access settings.$reconnectHint',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a second Reconnect tap while one waits starts no second timer', (
    tester,
  ) async {
    final listener = listenerChannel();
    await pumpSettings(tester, await settingsServices(listener: listener));
    int reconnects() =>
        listener.calls.where((c) => c.method == 'reconnect').length;
    await tester.tap(find.text('Reconnect listener'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Reconnect listener'));
    await tester.pump();
    expect(reconnects(), 1);
    // The result shows 1 s after the first tap, not after the second.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text('Listener connected.$reconnectHint'), findsOneWidget);
    // The next tap works again.
    await tester.tap(find.text('Reconnect listener'));
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
    await tester.tap(find.text('Reconnect listener'));
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
    expect(brightness(), Brightness.dark);
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    expect(await SharedPreferencesAsync().getBool('dark_mode'), false);
  });

  testWidgets('own categories can be added and removed, built-in ones cannot', (
    tester,
  ) async {
    await pumpSettings(tester, await settingsServices());
    expect(find.text('Built in'), findsNWidgets(7));
    expect(find.text('Your own'), findsNothing);
    expect(find.byTooltip('Remove category Food & Dining'), findsNothing);
    final add = find.widgetWithText(FilledButton, 'Add');
    expect(tester.widget<FilledButton>(add).onPressed, isNull);
    await tester.enterText(field('New category'), 'Gym');
    await tester.pump();
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsOneWidget);
    expect(find.text('Your own'), findsOneWidget);
    expect(
      tester.widget<TextField>(field('New category')).controller!.text,
      '',
    );
    await tester.tap(find.byTooltip('Remove category Gym'));
    await tester.pumpAndSettle();
    expect(find.text('Gym'), findsNothing);
    expect(find.text('Built in'), findsNWidgets(7));
  });

  testWidgets('the parser tool reads a sample text', (tester) async {
    await pumpSettings(tester, await settingsServices());
    await tester.enterText(field('Notification text'), sample);
    await tester.tap(find.text('Test parse'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Amount: MYR 15.00\nMerchant: RESTORAN CONTOH\nType: withdraw\nFormat: unknown',
      ),
      findsOneWidget,
    );
    await tester.enterText(field('Notification text'), 'Hello');
    await tester.tap(find.text('Test parse'));
    await tester.pumpAndSettle();
    expect(find.text('No rule matched this text'), findsOneWidget);
  });

  testWidgets('Use code and Check for updates open the online placeholder', (
    tester,
  ) async {
    await pumpSettings(tester, await settingsServices());
    final use = find.widgetWithText(FilledButton, 'Use code');
    expect(tester.widget<FilledButton>(use).onPressed, isNull);
    await tester.enterText(field('XXXX-XXXX'), 'ab12-cd34');
    await tester.pump();
    expect(
      tester.widget<TextField>(field('XXXX-XXXX')).controller!.text,
      'AB12-CD34',
    );
    await tester.tap(use);
    await tester.pumpAndSettle();
    expect(find.text(placeholder), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(placeholder), findsNothing);
    await tester.tap(find.text('Check for updates'));
    await tester.pumpAndSettle();
    expect(find.text(placeholder), findsOneWidget);
  });

  testWidgets('Check for updates is off when Online features is off', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      await settingsServices(prefs: {'online_features': false}),
    );
    expect(
      find.text(
        'Off: Koban makes no network calls. Groups and reading receipts with Claude stop.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Turn on Online features to check for updates.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Check for updates'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Online features'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'On: groups and reading receipts with Claude can use the internet.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Turn on Online features to check for updates.'),
      findsNothing,
    );
  });

  testWidgets('a stored invite code shows Accepted and Remove deletes it', (
    tester,
  ) async {
    await pumpSettings(
      tester,
      await settingsServices(prefs: {'device_token': 'token-1'}),
    );
    expect(find.text(accepted), findsOneWidget);
    expect(field('XXXX-XXXX'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(find.text(accepted), findsNothing);
    expect(field('XXXX-XXXX'), findsOneWidget);
    expect(await SharedPreferencesAsync().getString('device_token'), isNull);
  });

  testWidgets('on a Xiaomi phone the autostart row and the 7 steps show', (
    tester,
  ) async {
    final listener = listenerChannel(xiaomi: true);
    await pumpSettings(tester, await settingsServices(listener: listener));
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
      expect(find.text('Appearance'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsNothing);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsOneWidget);
    },
  );

  testWidgets(
    'Settings meets the tap target guidelines and works at text scale 1.3',
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
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );
}
