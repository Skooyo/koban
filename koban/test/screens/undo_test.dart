import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/undoable.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/ui/undo_snack_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../data/qr_store_test.dart' show pngBytes;
import '../support/harness.dart';
import 'home_screen_test.dart' show pay, pumpHome;
import 'notification_log_test.dart'
    show emptyAll, logChannel, pumpLog, postTime, stamp, row;
import 'person_screen_test.dart' show openPage, settle, settleReal, tapIn;
import 'person_view_model_test.dart' show d, seedAli;
import 'settings_test.dart' show pumpSettings, settingsServices;
import 'split_editor_test.dart' show addPayment, openEditor, saveDraft;

/// Every row of every table that a delete can touch.
Future<Map<String, List<Object>>> snapshot(AppServices s) async {
  final db = s.db;
  return {
    'expenses': await db.select(db.expenses).get(),
    'categories': await db.select(db.categories).get(),
    'bills': await db.select(db.splitBills).get(),
    'items': await db.select(db.splitItems).get(),
    'shares': await db.select(db.splitItemShares).get(),
    'debts': await db.select(db.splitDebts).get(),
    'people': await db.select(db.splitPeople).get(),
    'owed': await db.select(db.owedItems).get(),
  };
}

/// The rows are the same as [before]: same ids, same links, same values.
Future<void> expectBack(AppServices s, Map<String, List<Object>> before) async {
  final after = await snapshot(s);
  for (final table in before.keys) {
    expect(after[table], unorderedEquals(before[table]!), reason: table);
  }
}

/// Lets the snackbar run out: it stays 5 seconds, and it is gone after 6 and a little.
Future<void> waitOutUndo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  expect(find.text('Undo'), findsOneWidget);
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
  expect(find.text('Undo'), findsNothing);
  await settle(tester);
}

Future<void> tapUndo(WidgetTester tester) async {
  await tester.tap(find.text('Undo'));
  await settle(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('the Undo time is 6 seconds', () {
    expect(undoDuration, const Duration(seconds: 6));
  });

  testWidgets('payment: Undo restores the same row and its split link', (
    tester,
  ) async {
    final s = await testServices();
    await pay(s, '24.00', DateTime(2026, 11, 13, 9));
    final id = (await s.db.select(s.db.expenses).get()).single.id;
    await saveDraft(s, linkedExpenseId: id);
    final before = await snapshot(s);
    final original = (before['expenses']!.single as Expense);
    expect(original.categoryId, 'food');
    expect(original.countedAmount, d('10.00'));

    await pumpHome(tester, s);
    await tester.tap(find.text('Kedai Contoh').first);
    await settle(tester);
    await tester.tap(find.byTooltip('Delete payment'));
    await settle(tester);

    // No dialog: the page closed and Home shows the snackbar.
    expect(find.text('Delete this payment?'), findsNothing);
    expect(
      find.text('Payment deleted: Kedai Contoh, RM 24.00'),
      findsOneWidget,
    );
    expect(
      (await s.db.expenseById(id).getSingle()).status,
      ExpenseStatus.dismissed,
    );

    await tapUndo(tester);
    await expectBack(s, before);
    expect(find.text('Kedai Contoh'), findsWidgets);

    await tester.tap(find.text('Kedai Contoh').first);
    await settle(tester);
    await tester.tap(find.byTooltip('Delete payment'));
    await settle(tester);
    await waitOutUndo(tester);
    expect(
      (await s.db.expenseById(id).getSingle()).status,
      ExpenseStatus.dismissed,
    );
    expect(find.text('Kedai Contoh'), findsNothing);
  });

  testWidgets('split: Undo restores the bill, items, shares, debts and links', (
    tester,
  ) async {
    final s = await testServices();
    final payment = await addPayment(s);
    final billId = await saveDraft(s, linkedExpenseId: payment);
    // A received payment that the person page offers to settle with.
    await s.expenses.addManualExpense(
      amount: d('14.00'),
      merchant: 'Ali',
      postTime: DateTime(2026, 11, 13, 11).millisecondsSinceEpoch,
      type: TransactionType.receive,
    );
    final receive = (await s.db.select(s.db.expenses).get()).last.id;
    await (s.db.update(s.db.splitPeople))
        .write(SplitPeopleCompanion(suggestedSettleExpenseId: Value(receive)));
    final before = await snapshot(s);
    expect((before['expenses']!.first as Expense).countedAmount, d('10.00'));
    expect(before['items'], hasLength(2));
    expect(before['shares'], hasLength(3));

    final opener = await openEditor(tester, s, billId: billId);
    await tester.ensureVisible(find.text('Delete split'));
    await tester.tap(find.text('Delete split'));
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.text('Delete this split?'), findsNothing);
    expect(opener.closed, true);
    expect(find.text('Split deleted: Kedai Contoh'), findsOneWidget);
    final gone = await snapshot(s);
    for (final t in ['bills', 'items', 'shares', 'debts']) {
      expect(gone[t], isEmpty, reason: t);
    }
    expect((await s.db.expenseById(payment).getSingle()).countedAmount, isNull);

    await tapUndo(tester);
    await expectBack(s, before);

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete split'));
    await tester.tap(find.text('Delete split'));
    await tester.pumpAndSettle();
    await waitOutUndo(tester);
    final after = await snapshot(s);
    for (final t in ['bills', 'items', 'shares', 'debts']) {
      expect(after[t], isEmpty, reason: t);
    }
  });

  test(
    'split: a repayment and the counted amounts come back exactly',
    () async {
      final s = await testServices();
      final payment = await addPayment(s);
      await s.expenses.addManualExpense(
        amount: d('14.00'),
        merchant: 'Ali',
        postTime: DateTime(2026, 11, 13, 11).millisecondsSinceEpoch,
        type: TransactionType.receive,
      );
      final receive = (await s.db.select(s.db.expenses).get()).last.id;
      final billId = await saveDraft(s, linkedExpenseId: payment);
      final debt = (await s.db.select(s.db.splitDebts).get()).single;
      await s.splits.markPaid(debt.id, receive);
      final before = await snapshot(s);
      expect(
        (await s.db.expenseById(receive).getSingle()).countedAmount,
        d('0.00'),
      );
      expect(
        (await s.db.expenseById(payment).getSingle()).countedAmount,
        d('10.00'),
      );

      final undo = await s.splits.deleteSplit(billId);

      expect(
        (await s.db.expenseById(receive).getSingle()).countedAmount,
        isNull,
      );
      expect(
        (await s.db.expenseById(payment).getSingle()).countedAmount,
        isNull,
      );
      await undo!.undo();
      await expectBack(s, before);
      // A second Undo changes nothing.
      await undo.undo();
      await expectBack(s, before);
    },
  );

  test(
    'split: Undo does not take a payment that another split uses now',
    () async {
      final s = await testServices();
      final payment = await addPayment(s);
      final billId = await saveDraft(s, linkedExpenseId: payment);
      final undo = await s.splits.deleteSplit(billId);
      final other = await saveDraft(s, linkedExpenseId: payment);
      final counted =
          (await s.db.expenseById(payment).getSingle()).countedAmount;

      await undo!.undo();

      final bills = await s.db.select(s.db.splitBills).get();
      expect(bills.firstWhere((b) => b.id == billId).linkedExpenseId, isNull);
      expect(bills.firstWhere((b) => b.id == other).linkedExpenseId, payment);
      expect(
        (await s.db.expenseById(payment).getSingle()).countedAmount,
        counted,
      );
      expect(await s.db.debts(billId).get(), hasLength(1));
    },
  );

  for (final (row, message) in [
    ('Parking', 'Item deleted: Parking, RM 4.00'),
    ('Cash', 'Item deleted: Cash, RM 20.00'),
  ]) {
    testWidgets('person page: Undo restores the $row item', (tester) async {
      final s = await testServices();
      final ali = await seedAli(s);
      final before = await snapshot(s);
      await openPage(tester, s, ali);

      Future<void> deleteRow() async {
        await tapIn(tester, find.text(row));
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Delete'),
          ),
        );
        await settle(tester);
      }

      await deleteRow();
      expect(find.text('Delete this item?'), findsNothing);
      expect(find.text(message), findsOneWidget);
      expect(find.text(row), findsNothing);
      final gone = await snapshot(s);
      expect(gone['owed']!.length + gone['debts']!.length, 2);

      await tapUndo(tester);
      await expectBack(s, before);
      expect(find.text(row), findsOneWidget);

      await deleteRow();
      await waitOutUndo(tester);
      expect(find.text(row), findsNothing);
      final after = await snapshot(s);
      expect(after['owed']!.length + after['debts']!.length, 2);
    });
  }

  testWidgets(
    'person: Undo brings back the person, the paid items and the QR',
    (tester) async {
      final files = Directory.systemTemp.createTempSync('koban_files');
      addTearDown(() => files.deleteSync(recursive: true));
      final s = await testServices(filesDir: files);
      final ali = await seedAli(s);
      await s.people.settleUp(ali);
      final qr = File(p.join(files.path, 'qr', '$ali.img'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(pngBytes);
      await s.db.customStatement(
        'UPDATE split_people SET qrPath = ? WHERE id = ?',
        [qr.path, ali],
      );
      final before = await snapshot(s);
      final opener = await openPage(tester, s, ali);

      await tapIn(tester, find.byTooltip('Edit Ali'));
      await tapIn(tester, find.text('Delete person'));
      await settle(tester);

      expect(find.text('Delete Ali?'), findsNothing);
      expect(opener.closed, isTrue);
      // The QR file work ends last, and then the snackbar shows.
      await settleReal(
        tester,
        () => find.text('Ali deleted').evaluate().isNotEmpty,
      );
      expect(find.text('Ali deleted'), findsOneWidget);
      final gone = await snapshot(s);
      expect((gone['people']!.single as SplitPeopleData).archived, isTrue);
      expect(gone['owed'], isEmpty);
      expect(qr.existsSync(), isFalse);

      await tapUndo(tester);
      await expectBack(s, before);
      expect(qr.readAsBytesSync(), pngBytes);

      await tester.tap(find.text('Open person'));
      await settle(tester);
      await tapIn(tester, find.byTooltip('Edit Ali'));
      await tapIn(tester, find.text('Delete person'));
      await settle(tester);
      await settleReal(tester, () => find.text('Undo').evaluate().isNotEmpty);
      await waitOutUndo(tester);
      expect(
        ((await snapshot(s))['people']!.single as SplitPeopleData).archived,
        isTrue,
      );
      expect((await snapshot(s))['owed'], isEmpty);
      expect(qr.existsSync(), isFalse);
    },
  );

  testWidgets('settings: Undo restores a category and the payments keep it', (
    tester,
  ) async {
    final s = await settingsServices();
    await s.categories.addCategory('Gym', '#123456');
    final gym = (await s.categories.getAll()).firstWhere(
      (c) => c.name == 'Gym',
    );
    await s.expenses.addManualExpense(
      amount: d('30.00'),
      merchant: 'Gym One',
      postTime: DateTime(2026, 11, 13, 9).millisecondsSinceEpoch,
      categoryId: gym.id,
      type: TransactionType.withdraw,
    );
    final before = await snapshot(s);
    await pumpSettings(tester, s);
    await tester.tap(find.text('Categories and budgets'));
    await settle(tester);

    await tester.tap(find.byTooltip('Delete category Gym'));
    await settle(tester);
    expect(
      find.text('Gym deleted. 1 payment is now Uncategorized.'),
      findsOneWidget,
    );
    expect(await s.categories.getById(gym.id), isNull);

    await tapUndo(tester);
    await expectBack(s, before);
    expect(find.byTooltip('Delete category Gym'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete category Gym'));
    await settle(tester);
    await waitOutUndo(tester);
    expect(await s.categories.getById(gym.id), isNull);
    expect(find.byTooltip('Delete category Gym'), findsNothing);
  });

  testWidgets(
    'notification log: Clear log hides the rows and clears after 6 s',
    (tester) async {
      final listener = logChannel();
      await pumpLog(tester, await testServices(listener: listener));
      expect(find.textContaining(stamp(postTime)), findsNWidgets(3));

      await tester.tap(find.text('Clear log'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Log cleared'), findsOneWidget);
      expect(find.text(emptyAll), findsOneWidget);
      // A poll while the snackbar shows must not bring the rows back.
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.text(emptyAll), findsOneWidget);
      expect(listener.calls.where((c) => c.method == 'clearLog'), isEmpty);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.textContaining(stamp(postTime)), findsNWidgets(3));
      expect(listener.calls.where((c) => c.method == 'clearLog'), isEmpty);

      await tester.tap(find.text('Clear log'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      // The phone log is empty after the clear.
      listener.answers['recentNotifications'] = <Map<String, Object?>>[];
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Undo'), findsOneWidget);
      expect(listener.calls.where((c) => c.method == 'clearLog'), isEmpty);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pump();
      expect(listener.calls.where((c) => c.method == 'clearLog'), hasLength(1));
      expect(find.text(emptyAll), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    },
  );

  testWidgets('Clear log commit clears only the rows that were hidden', (
    tester,
  ) async {
    final listener = logChannel();
    await pumpLog(tester, await testServices(listener: listener));
    await tester.tap(find.text('Clear log'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    // A notification arrives while the snackbar shows.
    listener.answers['recentNotifications'] = [row('d')];
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pump();
    final clear = listener.calls.singleWhere((c) => c.method == 'clearLog');
    expect(
      (clear.arguments as Map)['ids'] as List,
      unorderedEquals(['a', 'b', 'c']),
    );
  });

  test(
    'split: Undo leaves a person who was archived before the delete',
    () async {
      final s = await testServices();
      final billId = await saveDraft(s);
      final ali = (await s.db.select(s.db.splitPeople).get()).single;
      await (s.db.update(s.db.splitPeople))
          .write(const SplitPeopleCompanion(archived: Value(true)));
      final undo = await s.splits.deleteSplit(billId);
      await undo!.undo();
      final after = (await s.db.person(ali.id).getSingle());
      expect(after.archived, isTrue);
    },
  );

  test('split: Undo un-archives a person archived after the delete', () async {
    final s = await testServices();
    final billId = await saveDraft(s);
    final ali = (await s.db.select(s.db.splitPeople).get()).single;
    final undo = await s.splits.deleteSplit(billId);
    await (s.db.update(s.db.splitPeople))
        .write(const SplitPeopleCompanion(archived: Value(true)));
    await undo!.undo();
    expect((await s.db.person(ali.id).getSingle()).archived, isFalse);
  });

  test(
    'owed item: Undo un-archives a person who was archived meanwhile',
    () async {
      final s = await testServices();
      final bo = await s.people.addPerson('Bo');
      await s.people.addOwedItem(bo, 'Teh', d('3.00'), 1);
      final item = (await s.db.select(s.db.owedItems).get()).single;
      final undo = await s.people.deleteOwedItem(item.id);
      await s.people.archivePerson(bo);
      expect((await s.db.person(bo).getSingle()).archived, isTrue);

      await undo!.undo();

      expect((await s.db.person(bo).getSingle()).archived, isFalse);
      expect(await s.db.select(s.db.owedItems).get(), [item]);
    },
  );

  test(
    'person: Undo does not write the QR back when the person was added again',
    () async {
      final files = Directory.systemTemp.createTempSync('koban_files');
      addTearDown(() => files.deleteSync(recursive: true));
      final s = await testServices(filesDir: files);
      final ali = await s.people.addPerson('Ali');
      final qr = File(p.join(files.path, 'qr', '$ali.img'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(pngBytes);
      await s.db.customStatement(
        'UPDATE split_people SET qrPath = ? WHERE id = ?',
        [qr.path, ali],
      );
      final undo = await s.people.archivePerson(ali);
      expect(qr.existsSync(), isFalse);
      expect(await s.people.addPerson('Ali'), ali);

      await undo!.undo();

      expect(qr.existsSync(), isFalse);
      expect((await s.db.person(ali).getSingle()).qrPath, isNull);
    },
  );

  testWidgets('a second Undo snackbar ends the first one at once', (
    tester,
  ) async {
    var firstCommits = 0;
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    showUndoSnackBar(
      messenger,
      'First',
      undo: Undoable(undo: () async {}, commit: () async => firstCommits++),
    );
    await tester.pumpAndSettle();
    showUndoSnackBar(messenger, 'Second', undo: Undoable(undo: () async {}));
    await tester.pumpAndSettle();
    expect(firstCommits, 1);
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });
}
