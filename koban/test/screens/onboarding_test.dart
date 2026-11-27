import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/capture/listener_control.dart';
import 'package:koban/screens/onboarding/onboarding_screen.dart';
import 'package:koban/theme/mon.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/harness.dart';

const maybank = 'com.maybank2u.life';
const tng = 'my.com.tngdigital.ewallet';

/// The listener channel of a new friend: no access yet.
FakeChannel newListener() => FakeChannel(ListenerControl.channelName, {
  'isAccessGranted': false,
  'isConnected': false,
  'isBatteryOptimizationIgnored': false,
  'isXiaomiFamily': false,
  'openBackgroundSettings': 'XIAOMI_AUTOSTART',
});

/// The device channel of an Android 14 phone without the alerts permission.
FakeChannel android14() => FakeChannel(deviceChannelName, {
  'sdkInt': 34,
  'notificationsAllowed': false,
  'shouldShowNotificationRationale': false,
  'requestNotificationPermission': false,
  'installedApps': [
    {'packageName': maybank, 'label': 'MAE', 'icon': null},
    {'packageName': tng, 'label': "Touch 'n Go", 'icon': null},
  ],
});

/// Pumps the app for a new friend. The auto-open shows onboarding.
Future<AppServices> pumpNewFriend(
  WidgetTester tester, {
  required FakeChannel listener,
  required FakeChannel device,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(411, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await testServices(listener: listener, device: device);
  await pumpKoban(tester, s, autoOpen: true, textScale: textScale);
  await tester.pumpAndSettle();
  return s;
}

/// The friend goes to another app and comes back.
Future<void> leaveAndComeBack(WidgetTester tester) async {
  final b = tester.binding;
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpAndSettle();
}

Iterable<String> methods(FakeChannel c) => c.calls.map((c) => c.method);

/// Goes from Welcome to the payment apps step: the friend turns on access in the settings.
Future<void> toApps(WidgetTester tester, FakeChannel listener) async {
  await tester.tap(find.text('Get started'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open notification settings'));
  await tester.pump();
  listener.answers['isAccessGranted'] = true;
  await leaveAndComeBack(tester);
}

/// Goes from Welcome to Keep Koban running.
Future<void> toRunning(WidgetTester tester, FakeChannel listener) async {
  await toApps(tester, listener);
  await tester.tap(find.text('Save 2 apps'));
  await tester.pumpAndSettle();
}

Future<void> expectGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

void main() {
  testWidgets('onboarding goes from Welcome to Notification access', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpNewFriend(
      tester,
      listener: newListener(),
      device: android14(),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    for (final t in [
      'Koban counts your spending for you.',
      'Reads payment notifications from the apps you pick.',
      'You check each payment before it counts.',
      'Payments stay on this phone. Online features are your choice.',
      'Get started',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.textContaining('Step '), findsNothing);
    await expectGuidelines(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final t in [
      'Set up Koban',
      'I need to see your notifications.',
      'Only the payment ones.',
      'Step 1 of 3 · Notifications',
      'Let Koban read payment notifications',
      'When your bank or e-wallet sends a payment notification, Koban turns it into a payment for you to check.',
      'Koban reads only the apps you pick in step 2.',
      'It ignores chats and all other notifications.',
      'Open notification settings',
      'In the list, tap Koban, then turn on Allow.',
      'Koban checks again when you come back.',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await expectGuidelines(tester);
    handle.dispose();
  });

  testWidgets('back from settings with access goes to the payment apps step', (
    tester,
  ) async {
    final listener = newListener();
    await pumpNewFriend(tester, listener: listener, device: android14());
    await toApps(tester, listener);
    expect(methods(listener), contains('openAccessSettings'));
    expect(find.text('Payment apps'), findsOneWidget);
    expect(find.text('Search apps'), findsOneWidget);
    expect(find.text('Save 2 apps'), findsOneWidget);
    expect(find.text('Step 2 of 3 · Payment apps'), findsOneWidget);
    // Back on the picker goes to the access step.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3 · Notifications'), findsOneWidget);
  });

  testWidgets(
    'back from settings without access on Android 14 shows the blocked help',
    (tester) async {
      final handle = tester.ensureSemantics();
      final listener = newListener();
      final device = android14();
      await pumpNewFriend(tester, listener: listener, device: device);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open notification settings'));
      await tester.pump();
      await leaveAndComeBack(tester);
      for (final t in [
        'Step 1 of 3 · Notifications',
        'Android blocked this',
        'Koban was installed from a file, so Android wants one more step.',
        '1  Tap Open app info below',
        '2  Tap ⋮ at the top right — Then tap Allow restricted settings',
        '3  Come back and tap Try again',
        'Android shows this item only after it blocks an app once.',
        'Open app info',
        'Try again',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      await expectGuidelines(tester);
      await tester.tap(find.text('Open app info'));
      await tester.pump();
      expect(methods(device), contains('openAppInfo'));
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(
        methods(listener).where((m) => m == 'openAccessSettings'),
        hasLength(2),
      );
      // A resume without the settings flag keeps the blocked help.
      await leaveAndComeBack(tester);
      expect(find.text('Android blocked this'), findsOneWidget);
      // Back on the blocked help goes to Welcome.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Koban counts your spending for you.'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets(
    'saving apps goes to Keep Koban running with the rows this phone needs',
    (tester) async {
      final handle = tester.ensureSemantics();
      final listener = newListener();
      final s = await pumpNewFriend(
        tester,
        listener: listener,
        device: android14(),
      );
      await toRunning(tester, listener);
      expect(s.settings.paymentApps.value, {maybank, tng});
      expect(s.settings.paymentAppsChosen.value, true);
      for (final t in [
        'Step 3 of 3 · Keep it running',
        'Keep Koban running',
        'Phones stop apps in the background to save battery. These settings keep tracking on.',
        'Notifications',
        'Tell me when tracking stops',
        'Allow',
        'Battery',
        'No restrictions',
        'Open settings',
        'Only the settings your phone needs show here.',
        'Next',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Skip for now'), findsNothing);
      expect(find.text('Autostart'), findsNothing);
      await expectGuidelines(tester);
      await tester.tap(find.text('Open settings'));
      await tester.pump();
      expect(methods(listener), contains('openBatteryOptimizationSettings'));
      // Back on the running step goes to the picker.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Search apps'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets(
    'Allow asks for the alerts permission, and the second time opens the settings',
    (tester) async {
      final handle = tester.ensureSemantics();
      final listener = newListener();
      final device = android14();
      await pumpNewFriend(tester, listener: listener, device: device);
      await toRunning(tester, listener);
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(
        methods(device).where((m) => m == 'requestNotificationPermission'),
        hasLength(1),
      );
      expect(methods(device), isNot(contains('openAppNotificationSettings')));
      // Android shows no dialog after two denials: the second tap opens the settings.
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(
        methods(device).where((m) => m == 'requestNotificationPermission'),
        hasLength(1),
      );
      expect(
        methods(device).where((m) => m == 'openAppNotificationSettings'),
        hasLength(1),
      );
      // The friend allows the alerts in the settings and comes back.
      device.answers['notificationsAllowed'] = true;
      await leaveAndComeBack(tester);
      expect(find.text('Allow'), findsNothing);
      expect(find.bySemanticsLabel('Notifications done'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets('Go to Home stores onboarding as done and closes', (
    tester,
  ) async {
    final listener = newListener();
    final s = await pumpNewFriend(
      tester,
      listener: listener,
      device: android14(),
    );
    await toRunning(tester, listener);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    for (final t in [
      'Koban is ready',
      'Pay with a card or e-wallet. The payment shows up in Koban within a few seconds.',
      'Go to Home',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // Back on Ready goes to the running step.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Keep Koban running'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final home = find.text('Go to Home');
    await tester.tap(home);
    await tester.tap(home, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(await SharedPreferencesAsync().getBool('onboarding_done'), true);
    expect(s.settings.onboardingDone.value, true);
    expect(find.text('Koban is ready'), findsNothing);
    expect(find.byType(KobanTabBar), findsOneWidget);
  });

  /// Goes to Ready with no app chosen.
  Future<AppServices> toReadyWithNoApp(
    WidgetTester tester,
    FakeChannel listener,
  ) async {
    final s = await pumpNewFriend(
      tester,
      listener: listener,
      device: android14(),
    );
    await toApps(tester, listener);
    await tester.tap(find.text('MAE'));
    await tester.tap(find.text("Touch 'n Go"));
    await tester.pump();
    await tester.tap(find.text('Save without apps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    return s;
  }

  testWidgets(
    'Ready with no app says so and Choose apps goes back to the picker',
    (tester) async {
      final listener = newListener();
      await toReadyWithNoApp(tester, listener);
      for (final t in [
        'Koban listens to no app yet.',
        'Choose the bank and wallet apps you pay with. Koban finds payments only in those apps.',
        'Choose apps',
        'Skip for now',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.byType(Mon), findsOneWidget);
      expect(find.text('Koban is ready'), findsNothing);
      expect(find.text('Go to Home'), findsNothing);
      await tester.tap(find.text('Choose apps'));
      await tester.pumpAndSettle();
      expect(find.text('Search apps'), findsOneWidget);
      await tester.tap(find.text('MAE'));
      await tester.pump();
      await tester.tap(find.text('Save 1 app'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Koban is ready'), findsOneWidget);
      expect(find.text('Go to Home'), findsOneWidget);
    },
  );

  testWidgets('Skip for now on Ready with no app stores onboarding as done', (
    tester,
  ) async {
    final s = await toReadyWithNoApp(tester, newListener());
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(s.settings.onboardingDone.value, true);
    expect(find.byType(KobanTabBar), findsOneWidget);
  });

  testWidgets('Back on Welcome closes the app and keeps onboarding due', (
    tester,
  ) async {
    final closed = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        closed.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final s = await pumpNewFriend(
      tester,
      listener: newListener(),
      device: android14(),
    );
    expect(find.text('Get started'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(closed, contains('SystemNavigator.pop'));
    expect(await SharedPreferencesAsync().getBool('onboarding_done'), isNull);
    expect(s.settings.onboardingDone.value, false);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets('Autostart shows Checked by you after the friend comes back', (
    tester,
  ) async {
    final listener = newListener();
    listener.answers['isXiaomiFamily'] = true;
    final s = await pumpNewFriend(
      tester,
      listener: listener,
      device: android14(),
    );
    await toRunning(tester, listener);
    expect(find.text('Autostart'), findsOneWidget);
    expect(find.text('Checked by you'), findsNothing);
    // The battery row opens a page too, but only Autostart counts as checked.
    await tester.tap(find.text('Open settings').last);
    await tester.pump();
    expect(methods(listener), contains('openBackgroundSettings'));
    expect(find.text('Checked by you'), findsNothing);
    await leaveAndComeBack(tester);
    expect(find.text('Checked by you'), findsOneWidget);
    expect(s.settings.onboardingAutostartChecked, true);
  });

  testWidgets(
    'onboarding comes back after Android stops the app in the access settings',
    (tester) async {
      await pumpNewFriend(tester, listener: newListener(), device: android14());
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open notification settings'));
      await tester.pump();
      // Android stops the app. The friend turns on access and starts the app again.
      await tester.pumpWidget(const SizedBox());
      final stored = await SharedPreferencesAsync().getAll();
      final listener = newListener();
      listener.answers['isAccessGranted'] = true;
      final s = await testServices(
        listener: listener,
        device: android14(),
        prefs: {
          for (final e in stored.entries)
            if (e.value != null) e.key: e.value!,
        },
      );
      await pumpKoban(tester, s, autoOpen: true);
      await tester.pumpAndSettle();
      // The step after access, in onboarding: not the picker alone.
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Search apps'), findsOneWidget);
      await tester.tap(find.text('Save 2 apps'));
      await tester.pumpAndSettle();
      expect(find.text('Keep Koban running'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();
      expect(find.byType(KobanTabBar), findsOneWidget);
      final prefs = SharedPreferencesAsync();
      expect(await prefs.getBool('onboarding_done'), true);
      expect(await prefs.getString('flutter_onboarding_step'), isNull);
      expect(await prefs.getBool('flutter_onboarding_opened_settings'), isNull);
    },
  );
}
