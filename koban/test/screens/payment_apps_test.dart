import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/routes.dart';
import 'package:koban/device/device_control.dart';
import 'package:koban/screens/payment_apps/payment_apps_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../capture/fake_capture_host.dart';
import '../support/harness.dart';

const maybank = 'com.maybank2u.life';
const tng = 'my.com.tngdigital.ewallet';

InstalledApp app(String pkg, String label) =>
    InstalledApp(packageName: pkg, label: label, icon: null);

/// A page with one button that opens the payment apps picker.
class Opener extends StatelessWidget {
  const Opener({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => openPaymentApps(context),
        child: const Text('Open apps'),
      ),
    ),
  );
}

FakeChannel threeApps() => FakeChannel(deviceChannelName, {
  'installedApps': [
    {'packageName': 'com.example.chat', 'label': 'Chat', 'icon': null},
    {'packageName': tng, 'label': "Touch 'n Go", 'icon': null},
    {'packageName': maybank, 'label': 'MAE', 'icon': null},
  ],
});

Future<void> openPicker(
  WidgetTester tester,
  AppServices s, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(411, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpKoban(tester, s, home: const Opener(), textScale: textScale);
  await tester.tap(find.text('Open apps'));
  await tester.pumpAndSettle();
}

Finder get rows => find.byType(Checkbox);

void main() {
  test('preselected apps come first, then the label order', () {
    final sorted = sortApps(
      [
        app('c', 'Zed'),
        app('tng', 'Touch n Go'),
        app('a', 'apple'),
        app('mb', 'Maybank'),
      ],
      {'mb', 'tng'},
    );
    expect([for (final a in sorted) a.packageName], ['mb', 'tng', 'a', 'c']);
  });

  test('apps with equal labels keep a fixed order by package name', () {
    final sorted = sortApps([
      app('b.app', 'Same'),
      app('a.app', 'same'),
      app('c.app', 'SAME'),
    ], {});
    expect(
      [for (final a in sorted) a.packageName],
      ['a.app', 'b.app', 'c.app'],
    );
  });

  test('the first open ticks only the installed preselected apps', () {
    expect(
      initialSelection(
        chosen: false,
        allowlist: {'x'},
        installed: {'mb', 'x'},
        preselect: {'mb', 'tng'},
      ),
      {'mb'},
    );
  });

  test('a later open ticks the stored list', () {
    expect(
      initialSelection(
        chosen: true,
        allowlist: {'x'},
        installed: {'mb', 'x'},
        preselect: {'mb', 'tng'},
      ),
      {'x'},
    );
    expect(
      initialSelection(
        chosen: true,
        allowlist: {},
        installed: {'mb'},
        preselect: {'mb'},
      ),
      <String>{},
    );
  });

  testWidgets('the picker lists the apps with the preselected ones ticked', (
    tester,
  ) async {
    await openPicker(tester, await testServices(device: threeApps()));
    expect(find.text('Payment apps'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(
      find.text('Koban reads notifications only from the apps you tick.'),
      findsOneWidget,
    );
    expect(find.text('Search apps'), findsOneWidget);
    expect(rows, findsNWidgets(3));
    expect(
      [for (final c in tester.widgetList<Checkbox>(rows)) c.value],
      [true, true, false],
    );
    expect(find.text('MAE'), findsOneWidget);
    expect(find.text('Save 2 apps'), findsOneWidget);
  });

  testWidgets('search filters by label and says when nothing matches', (
    tester,
  ) async {
    await openPicker(tester, await testServices(device: threeApps()));
    await tester.enterText(find.byType(TextField), 'mae');
    await tester.pumpAndSettle();
    expect(rows, findsOneWidget);
    expect(find.text('MAE'), findsOneWidget);
    expect(find.text('No apps match.'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(rows, findsNothing);
    expect(find.text('No apps match.'), findsOneWidget);
  });

  testWidgets('save stores the list and the native copy and closes', (
    tester,
  ) async {
    final s = await testServices(device: threeApps());
    await openPicker(tester, s);
    await tester.tap(find.text("Touch 'n Go"));
    await tester.pumpAndSettle();
    expect(find.text('Save 1 app'), findsOneWidget);
    await tester.tap(find.text('Save 1 app'));
    await tester.pumpAndSettle();
    final prefs = SharedPreferencesAsync();
    expect(await prefs.getStringList('payment_app_allowlist'), [maybank]);
    expect(await prefs.getBool('payment_apps_chosen'), true);
    expect((s.captureHost as FakeCaptureHost).paymentApps, {maybank});
    expect(s.settings.paymentApps.value, {maybank});
    expect(s.settings.paymentAppsChosen.value, true);
    expect(find.text('Payment apps'), findsNothing);
    expect(find.text('Open apps'), findsOneWidget);
  });

  testWidgets('Home asks to choose payment apps when none is chosen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await testServices(
      device: threeApps(),
      prefs: {'payment_apps_chosen': true},
    );
    await pumpKoban(tester, s);
    await tester.pumpAndSettle();
    const row = 'Koban listens to no app. Choose your payment apps.';
    expect(find.text(row), findsOneWidget);
    // A friend who listens to no app does not see the first-payment card.
    expect(find.text('Waiting for your first payment'), findsNothing);
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    expect(find.text('Payment apps'), findsOneWidget);
    // The stored list is empty and chosen: nothing is ticked.
    expect(find.text('Save without apps'), findsOneWidget);
  });

  testWidgets('two taps on Save in one frame save once and close one page', (
    tester,
  ) async {
    final s = await testServices(device: threeApps());
    await openPicker(tester, s);
    final save = find.text('Save 2 apps');
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Open apps'), findsOneWidget);
    expect(find.text('Payment apps'), findsNothing);
    expect(
      await SharedPreferencesAsync().getStringList('payment_app_allowlist'),
      [maybank, tng],
    );
  });

  testWidgets(
    'a row is a check box for screen readers and a tap toggles once',
    (tester) async {
      final handle = tester.ensureSemantics();
      await openPicker(tester, await testServices(device: threeApps()));
      SemanticsNode mae() => tester.getSemantics(find.text('MAE'));
      expect(mae().getSemanticsData().flagsCollection.isChecked.name, 'isTrue');
      expect(find.text('Save 2 apps'), findsOneWidget);
      await tester.tap(find.text('MAE'));
      await tester.pumpAndSettle();
      expect(find.text('Save 1 app'), findsOneWidget);
      expect(
        mae().getSemanticsData().flagsCollection.isChecked.name,
        'isFalse',
      );
      // A tap on the check box goes to the row: one toggle.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('Save 2 apps'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets(
    'the picker meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      await openPicker(
        tester,
        await testServices(device: threeApps()),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );
}
