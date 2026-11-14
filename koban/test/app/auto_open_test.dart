import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/app/routes.dart';
import 'package:koban/capture/listener_control.dart';
import 'package:koban/screens/check/check_payments_screen.dart';
import 'package:koban/screens/onboarding/onboarding_screen.dart';
import 'package:koban/screens/payment_apps/payment_apps_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../screens/check_payments_view_model_test.dart' show addCard, maeDevice;
import '../support/harness.dart';

/// App services for a friend with the access answer [access] and [cards] waiting cards.
Future<AppServices> friend({
  required bool access,
  required bool chosen,
  required int cards,
  bool done = false,
}) async {
  final s = await testServices(
    listener: FakeChannel(ListenerControl.channelName, {
      'isAccessGranted': access,
      'isConnected': access,
    }),
    device: maeDevice(),
    prefs: {'onboarding_done': done, 'payment_apps_chosen': chosen},
  );
  for (var i = 0; i < cards; i++) {
    await addMaeCard(s, i);
  }
  return s;
}

Future<void> addMaeCard(AppServices s, int order) => addCard(
  s,
  order: order,
  amount: '15.00',
  merchant: 'RESTORAN CONTOH',
  rawText: 'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.',
);

/// Pumps the app with the auto-open on, as `main` starts it.
Future<void> start(WidgetTester tester, AppServices s) async {
  tester.view.physicalSize = const Size(411, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpKoban(tester, s, autoOpen: true);
}

/// The app goes to the background and comes back to the front.
void leaveAndComeBack(WidgetTester tester) {
  final b = tester.binding;
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

/// Each page on the stack, also the pages under the top page.
Finder all(Type t) => find.byType(t, skipOffstage: false);

void main() {
  testWidgets('a new user gets onboarding first', (tester) async {
    await start(tester, await friend(access: false, chosen: false, cards: 2));
    await tester.pumpAndSettle();
    expect(find.text('Koban counts your spending for you.'), findsOneWidget);
    expect(all(OnboardingScreen), findsOneWidget);
    expect(all(PaymentAppsScreen), findsNothing);
    expect(all(CheckPaymentsScreen), findsNothing);
  });

  testWidgets(
    'a user with access and no app choice gets the payment apps picker',
    (tester) async {
      await start(tester, await friend(access: true, chosen: false, cards: 2));
      await tester.pumpAndSettle();
      expect(find.text('Search apps'), findsOneWidget);
      expect(all(PaymentAppsScreen), findsOneWidget);
      expect(all(OnboardingScreen), findsNothing);
      expect(all(CheckPaymentsScreen), findsNothing);
    },
  );

  testWidgets('a user with waiting cards gets Check payments', (tester) async {
    await start(tester, await friend(access: true, chosen: true, cards: 2));
    // The app comes to the front in the first frame too. Check payments opens one time.
    leaveAndComeBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('Check payments'), findsOneWidget);
    expect(all(CheckPaymentsScreen), findsOneWidget);
    expect(all(OnboardingScreen), findsNothing);
    // Back shows Home. The auto-open does not open the page again.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(all(CheckPaymentsScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('an existing user with access never gets onboarding', (
    tester,
  ) async {
    await start(tester, await friend(access: true, chosen: true, cards: 0));
    await tester.pumpAndSettle();
    leaveAndComeBack(tester);
    await tester.pumpAndSettle();
    expect(all(OnboardingScreen), findsNothing);
    expect(all(PaymentAppsScreen), findsNothing);
    expect(all(CheckPaymentsScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('auto-open runs again when the app comes back to the front', (
    tester,
  ) async {
    final s = await friend(access: true, chosen: true, cards: 0);
    await start(tester, s);
    await tester.pumpAndSettle();
    expect(all(CheckPaymentsScreen), findsNothing);
    await addMaeCard(s, 0);
    leaveAndComeBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('Check payments'), findsOneWidget);
    expect(all(CheckPaymentsScreen), findsOneWidget);
  });

  testWidgets('auto-open does nothing while another page is open', (
    tester,
  ) async {
    final s = await friend(access: true, chosen: true, cards: 0);
    await start(tester, s);
    await tester.pumpAndSettle();
    pushPage<void>(
      tester.element(find.byType(NavigationBar)),
      const Scaffold(body: Text('Other page')),
    );
    await tester.pumpAndSettle();
    await addMaeCard(s, 0);
    leaveAndComeBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('Other page'), findsOneWidget);
    expect(all(CheckPaymentsScreen), findsNothing);
  });

  testWidgets('the tab shell with no autoOpen argument opens the due page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await friend(access: false, chosen: false, cards: 0);
    await pumpKoban(tester, s, home: const HomeShell());
    await tester.pumpAndSettle();
    expect(find.text('Koban counts your spending for you.'), findsOneWidget);
    expect(all(OnboardingScreen), findsOneWidget);
  });
}
