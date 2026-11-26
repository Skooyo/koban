import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/app/routes.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/data/database.dart' show SplitPeopleData;
import 'package:koban/rules/split_math.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/activity/activity_screen.dart';
import 'package:koban/screens/home/home_screen.dart';
import 'package:koban/screens/people/people_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../screens/check_payments_view_model_test.dart' show addCard, maeDevice;
import '../support/harness.dart';

BuildContext homeContext(WidgetTester tester) =>
    tester.element(find.byType(HomeShell));

/// Lets the database work end. Its streams need real time in a widget test.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

/// Opens a route with [open], finds [title] on the top route, and goes back.
/// [inside] gets an element of the top route before the pop.
Future<void> visit(
  WidgetTester tester,
  Future<void> Function(BuildContext) open,
  String title, {
  void Function(BuildContext)? inside,
}) async {
  final done = open(homeContext(tester));
  await settle(tester);
  final onTop = find
      .text(title)
      .evaluate()
      .where((e) => ModalRoute.of(e)?.isCurrent == true)
      .toList();
  expect(onTop, isNotEmpty, reason: '$title on the top route');
  expect(tester.takeException(), isNull, reason: title);
  inside?.call(onTop.first);
  Navigator.of(onTop.first).pop();
  await tester.pumpAndSettle();
  await done;
}

void main() {
  testWidgets('every 0.1.1 route opens its Flutter screen', (tester) async {
    final s = await testServices(
      prefs: {'payment_apps_chosen': true},
      device: maeDevice(),
    );
    await addCard(
      s,
      order: 0,
      amount: '15.00',
      merchant: 'RESTORAN CONTOH',
      rawText:
          'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.',
    );
    final ali = await s.people.addPerson('Ali');
    await s.people.addPerson('Mei');
    await s.expenses.addManualExpense(
      amount: Decimal.parse('24.00'),
      merchant: 'Kedai Contoh',
      postTime: DateTime(2026, 11, 11, 20, 15).millisecondsSinceEpoch,
      type: TransactionType.withdraw,
    );
    final expenseId = (await s.db.select(s.db.expenses).get()).last.id;
    final billId = await s.splits.saveSplit(
      SplitDraft(
        billId: null,
        merchant: 'Kedai Contoh',
        billTime: DateTime(2026, 11, 13, 12).millisecondsSinceEpoch,
        currency: 'MYR',
        printedTotal: null,
        items: [
          DraftItem(
            name: 'Nasi lemak',
            quantity: 1,
            price: Decimal.parse('20.00'),
            sharedBy: {meId, 'a'},
          ),
        ],
        charges: SplitCharges(),
        people: const [
          SplitPeopleData(id: 'a', name: 'Ali', lastUsedAt: 0, archived: false),
        ],
        linkedExpenseId: null,
      ),
    );
    await pumpKoban(tester, s);
    await settle(tester);

    // Tabs: home, activity, people, groups.
    Finder inTab<T extends Widget>(String text) =>
        find.descendant(of: find.byType(T), matching: find.text(text));
    final shell = tester.state<HomeShellState>(find.byType(HomeShell));
    expect(inTab<HomeScreen>('Fri, 13 Nov'), findsWidgets);
    shell.select(KobanTab.activity);
    await tester.pumpAndSettle();
    expect(inTab<ActivityScreen>('Activity'), findsWidgets);
    shell.select(KobanTab.people);
    await tester.pumpAndSettle();
    expect(inTab<PeopleScreen>('People'), findsWidgets);
    shell.select(KobanTab.groups);
    await tester.pumpAndSettle();
    expect(find.text('Groups'), findsWidgets);
    shell.select(KobanTab.home);
    await tester.pumpAndSettle();

    await visit(tester, (c) => openPerson(c, ali), 'Ali');
    await visit(tester, (c) => openSplitNew(c), 'Split a bill');
    await visit(tester, (c) => openSplitEdit(c, billId), 'Split done');
    await visit(tester, (c) => openPaymentNew(c), 'Save payment');
    await visit(tester, (c) => openPaymentEdit(c, expenseId), 'Payment');
    await visit(tester, openCheckPayments, 'Check payments');
    await visit(tester, openSettings, 'Settings');
    await visit(tester, openPaymentApps, 'Payment apps');
    await visit(tester, openNotificationLog, 'Notification log');
    // The group is not loaded here: the page shows its loading title.
    await visit(tester, (c) => openGroup(c, 'g1'), 'Group');
    await visit(tester, openOnboarding, 'Koban counts your spending for you.');
  });

  testWidgets('the app works in the light theme', (tester) async {
    final s = await testServices(
      prefs: {'dark_mode': false, 'payment_apps_chosen': true},
      device: maeDevice(),
    );
    await addCard(
      s,
      order: 0,
      amount: '15.00',
      merchant: 'RESTORAN CONTOH',
      rawText:
          'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.',
    );
    await pumpKoban(tester, s);
    await tester.pumpAndSettle();
    Brightness brightness() =>
        Theme.of(tester.element(find.byType(HomeScreen, skipOffstage: false)))
            .brightness;
    expect(brightness(), Brightness.light);

    final shell = tester.state<HomeShellState>(find.byType(HomeShell));
    shell.select(KobanTab.activity);
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);

    void light(BuildContext c) =>
        expect(Theme.of(c).brightness, Brightness.light);
    await visit(
      tester,
      (c) => openPaymentNew(c),
      'Save payment',
      inside: light,
    );
    await visit(tester, openCheckPayments, 'Check payments', inside: light);
    expect(tester.takeException(), isNull);
  });
}
