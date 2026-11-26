import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/capture/listener_control.dart';
import 'package:koban/rules/periods.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/home/home_view_model.dart';

import '../support/harness.dart';

Future<void> pay(AppServices s, String amount, DateTime at) =>
    s.expenses.addManualExpense(
      amount: Decimal.parse(amount),
      merchant: 'Kedai Contoh',
      postTime: at.millisecondsSinceEpoch,
      categoryId: 'food',
      notes: null,
      type: TransactionType.withdraw,
    );

/// Lets the streams answer.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the summaries cover today, this week and this month', () async {
    final s = await testServices();
    await pay(s, '12.50', DateTime(2026, 11, 13, 9));
    await pay(s, '7.00', DateTime(2026, 11, 10, 9));
    await pay(s, '3.00', DateTime(2026, 11, 2, 9));
    final vm = HomeViewModel(s);
    addTearDown(vm.dispose);
    await vm.refresh();
    await settle();
    expect(vm.today!.total, Decimal.parse('12.5'));
    expect(vm.week!.total, Decimal.parse('19.5'));
    expect(vm.month!.total, Decimal.parse('22.5'));
    expect(vm.isAccessGranted, true);
    expect(vm.hasAnyPayment, true);
    expect(vm.importFailed, false);
    expect(vm.categoryNames['food'], 'Food & Dining');
  });

  test('a new day at refresh moves Today on', () async {
    var time = DateTime(2026, 11, 13, 12);
    final s = await testServices();
    // The services keep one clock. This test uses its own services with a clock that moves.
    final moving = AppServices(
      db: s.db,
      settings: s.settings,
      importResult: s.importResult,
      listener: s.listener,
      paymentApps: s.paymentApps,
      captureHost: s.captureHost,
      device: s.device,
      online: s.online,
      now: () => time,
    );
    await pay(moving, '12.50', DateTime(2026, 11, 13, 9));
    final vm = HomeViewModel(moving);
    addTearDown(vm.dispose);
    await vm.refresh();
    await settle();
    expect(vm.today!.total, Decimal.parse('12.5'));

    time = DateTime(2026, 11, 14, 0, 1);
    await vm.refresh();
    await settle();
    expect(vm.today!.total, Decimal.zero);
    expect(vm.week!.total, Decimal.parse('12.5'));
  });

  test(
    'a new day moves on and refresh ends when the access check throws',
    () async {
      var time = DateTime(2026, 11, 13, 12);
      final s = await testServices();
      final moving = AppServices(
        db: s.db,
        settings: s.settings,
        importResult: s.importResult,
        listener: s.listener,
        paymentApps: s.paymentApps,
        captureHost: s.captureHost,
        device: s.device,
        online: s.online,
        now: () => time,
      );
      await pay(moving, '12.50', DateTime(2026, 11, 13, 9));
      final vm = HomeViewModel(moving);
      addTearDown(vm.dispose);
      await vm.refresh();
      await settle();
      expect(vm.today!.total, Decimal.parse('12.5'));

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel(ListenerControl.channelName),
        (call) async => throw PlatformException(code: 'boom'),
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel(ListenerControl.channelName),
          null,
        ),
      );
      time = DateTime(2026, 11, 14, 0, 1);
      // The screen calls refresh without a wait, so a platform error must stay inside.
      await vm.refresh();
      await settle();
      expect(vm.today!.total, Decimal.zero);
      expect(vm.isAccessGranted, true);
    },
  );

  test(
    'select activity with the week shows this month and this week',
    () async {
      final s = await testServices();
      final vm = HomeViewModel(s);
      addTearDown(vm.dispose);
      vm.selectActivity(withWeek: true);
      var v = s.activitySelection.value;
      expect(v.month, const YearMonth(2026, 11));
      expect(v.weekStart, DateTime(2026, 11, 9).millisecondsSinceEpoch);
      expect(v.categoryFilter, isNull);

      vm.selectActivity(withWeek: false);
      v = s.activitySelection.value;
      expect(v.month, const YearMonth(2026, 11));
      expect(v.weekStart, isNull);
    },
  );

  test('a week that began last month opens on the 1st', () async {
    // Wednesday 2 Dec 2026: the week began on Monday 30 Nov.
    final s = await testServices(now: DateTime(2026, 12, 2, 12));
    final vm = HomeViewModel(s);
    addTearDown(vm.dispose);
    vm.selectActivity(withWeek: true);
    expect(s.activitySelection.value.month, const YearMonth(2026, 12));
    expect(
      s.activitySelection.value.weekStart,
      DateTime(2026, 12, 1).millisecondsSinceEpoch,
    );
  });
}
