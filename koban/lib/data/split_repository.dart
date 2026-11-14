import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../rules/people_math.dart';
import '../rules/repayment_matcher.dart';
import '../rules/split_math.dart';
import '../rules/types.dart';
import 'database.dart';
import 'ids.dart';
import 'user_error.dart';
import 'watch.dart';

/// One line of a draft split.
class DraftItem {
  const DraftItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.sharedBy,
  });

  final String name;
  final int quantity;

  /// Line price: what the whole line costs.
  final Decimal price;
  final Set<String> sharedBy;
}

/// A split that the user edits. [people] excludes the owner.
/// [DraftItem.sharedBy] holds person ids from [people], or [meId].
class SplitDraft {
  const SplitDraft({
    required this.billId,
    required this.merchant,
    required this.billTime,
    required this.currency,
    required this.printedTotal,
    required this.items,
    required this.charges,
    required this.people,
    required this.linkedExpenseId,
  });

  final String? billId;
  final String? merchant;
  final int billTime;
  final String currency;
  final Decimal? printedTotal;
  final List<DraftItem> items;
  final SplitCharges charges;
  final List<SplitPeopleData> people;
  final String? linkedExpenseId;
}

/// An open debt with the names that the debts screen shows.
class OpenDebtView {
  const OpenDebtView({
    required this.debt,
    required this.personName,
    required this.billMerchant,
    required this.billTime,
    required this.suggestedRepayment,
    this.manual = false,
  });

  final SplitDebt debt;
  final String personName;
  final String? billMerchant;
  final int billTime;
  final Expense? suggestedRepayment;

  /// Added by hand on the page of the person. It opens an edit form, not the split editor.
  final bool manual;
}

const _paymentWindowMs = 3 * 24 * 60 * 60 * 1000;
const _repaymentLeadMs = 24 * 60 * 60 * 1000;
final _zeroMoney = Decimal.parse('0.00');

Decimal _sum(Iterable<Decimal> values) =>
    values.fold(Decimal.zero, (s, v) => s + v);

/// The splits, their debts and the repayments. A port of `SplitRepository.kt`.
class SplitRepository {
  SplitRepository(this._db, {required this._now});

  final KobanDatabase _db;
  final int Function() _now;

  Stream<List<SplitBill>> watchBills() => _db.bills().watch();

  Stream<List<SplitPeopleData>> watchRecentPeople() => _db.people().watch();

  Stream<List<OpenDebtView>> watchOpenDebts() => watchTables(
    _db,
    {_db.splitDebts, _db.splitPeople, _db.splitBills},
    () async {
      final rows = await _db.openDebtRows().get();
      final views = <OpenDebtView>[];
      for (final row in rows) {
        final debt = await _db.debt(row.debtId).getSingleOrNull();
        if (debt == null) continue;
        final suggestedId = debt.suggestedRepaymentExpenseId;
        views.add(
          OpenDebtView(
            debt: debt,
            personName: row.personName,
            billMerchant: row.merchant,
            billTime: row.billTime,
            suggestedRepayment: suggestedId == null
                ? null
                : await _db.expenseById(suggestedId).getSingleOrNull(),
            manual: row.manual,
          ),
        );
      }
      return views;
    },
  );

  Future<SplitBill?> billForExpense(String expenseId) =>
      _db.billByLinkedExpense(expenseId).getSingleOrNull();

  Future<bool> isLocked(String billId) async =>
      (await _db.debts(billId).get()).any((d) => d.status == DebtStatus.paid);

  Future<SplitDraft?> loadDraft(String billId) async {
    final bill = await _db.bill(billId).getSingleOrNull();
    if (bill == null) return null;
    final items = await _db.items(billId).get();
    final sharesByItem = <String, List<String>>{};
    for (final s in await _db.shares(billId).get()) {
      (sharesByItem[s.itemId] ??= []).add(s.personId);
    }
    final peopleById = {
      for (final p in await _db.allPeopleIncludingArchived().get()) p.id: p,
    };
    final usedIds = {
      for (final ids in sharesByItem.values) ...ids,
      for (final d in await _db.debts(billId).get()) d.personId,
    }..remove(meId);
    return SplitDraft(
      billId: bill.id,
      merchant: bill.merchant,
      billTime: bill.billTime,
      currency: bill.currency,
      printedTotal: bill.printedTotal,
      items: [
        for (final it in items)
          DraftItem(
            name: it.name,
            quantity: it.quantity,
            price: it.price,
            sharedBy: (sharesByItem[it.id] ?? const []).toSet(),
          ),
      ],
      charges: SplitCharges(
        serviceCharge: bill.serviceCharge,
        tax: bill.tax,
        discount: bill.discount,
        rounding: bill.rounding,
      ),
      people: [
        for (final id in usedIds)
          if (peopleById[id] != null) peopleById[id]!,
      ],
      linkedExpenseId: bill.linkedExpenseId,
    );
  }

  Future<String> saveSplit(SplitDraft draft) => _db.transaction(() async {
    final billId = draft.billId ?? newId();
    final existing = draft.billId == null
        ? null
        : await _db.bill(draft.billId!).getSingleOrNull();
    if (existing != null && await isLocked(billId)) {
      throw const KobanUserError(
        "This split already has a repayment, so it can't change.",
      );
    }
    final now = _now();

    // Map each draft person id to a stored person by normalized name.
    // A match revives an archived person. Active people come first.
    final all = await _db.allPeopleIncludingArchived().get();
    final stored = [
      ...all.where((p) => !p.archived),
      ...all.where((p) => p.archived),
    ];
    final idMap = <String, String>{meId: meId};
    for (final person in draft.people) {
      final name = person.name.trim();
      final key = PeopleMath.normalizedName(name);
      final match = stored
          .where((p) => PeopleMath.normalizedName(p.name) == key)
          .firstOrNull;
      final resolved =
          (match ??
                  SplitPeopleData(
                    id: newId(),
                    name: name,
                    lastUsedAt: now,
                    archived: false,
                  ))
              .copyWith(lastUsedAt: now, archived: false);
      await _upsertPerson(resolved);
      if (match == null) stored.add(resolved);
      idMap[person.id] = resolved.id;
    }

    final oldDebtPeople = [
      for (final d in await _db.debts(billId).get()) d.personId,
    ];
    await _db.deleteSharesByBill(billId);
    await _db.deleteItemsByBill(billId);
    await _db.deleteDebtsByBill(billId);

    final itemRows = [
      for (var i = 0; i < draft.items.length; i++)
        SplitItem(
          id: newId(),
          billId: billId,
          name: draft.items[i].name,
          quantity: draft.items[i].quantity,
          price: draft.items[i].price,
          position: i,
        ),
    ];
    final shareRows = [
      for (var i = 0; i < draft.items.length; i++)
        for (final p in draft.items[i].sharedBy)
          SplitItemShare(itemId: itemRows[i].id, personId: idMap[p]!),
    ];
    final inputs = [
      for (final item in draft.items)
        SplitItemInput(
          price: item.price,
          sharedBy: {for (final p in item.sharedBy) idMap[p]!},
        ),
    ];
    final debtRows = [
      for (final e in SplitMath.shares(inputs, draft.charges).entries)
        if (e.key != meId && e.value.sign != 0)
          SplitDebt(
            id: newId(),
            billId: billId,
            personId: e.key,
            amount: e.value,
            status: DebtStatus.open,
            repaymentExpenseId: null,
            suggestedRepaymentExpenseId: null,
            paidAt: null,
          ),
    ];

    await _insertBill(
      SplitBill(
        id: billId,
        merchant: draft.merchant,
        billTime: draft.billTime,
        currency: draft.currency,
        printedTotal: draft.printedTotal,
        serviceCharge: draft.charges.serviceCharge,
        tax: draft.charges.tax,
        discount: draft.charges.discount,
        rounding: draft.charges.rounding,
        linkedExpenseId: existing?.linkedExpenseId,
        createdAt: existing?.createdAt ?? now,
        manual: false,
      ),
    );
    await _db.batch((b) {
      b.insertAll(_db.splitItems, itemRows, mode: InsertMode.insertOrReplace);
      b.insertAll(
        _db.splitItemShares,
        shareRows,
        mode: InsertMode.insertOrReplace,
      );
      b.insertAll(_db.splitDebts, debtRows, mode: InsertMode.insertOrReplace);
    });
    for (final id in {...oldDebtPeople, ...debtRows.map((d) => d.personId)}) {
      await clearSettleSuggestion(id);
    }

    await _applyLink(billId, draft.linkedExpenseId);
    return billId;
  });

  Future<void> linkPayment(String billId, String? expenseId) =>
      _db.transaction(() => _applyLink(billId, expenseId));

  /// Moves the link of the bill to [expenseId], clears the old expense, and recomputes the new one.
  Future<void> _applyLink(String billId, String? expenseId) async {
    final bill = await _db.bill(billId).getSingleOrNull();
    if (bill == null) return;
    final oldId = bill.linkedExpenseId;
    if (expenseId != null) {
      final owner =
          (await _db.billByLinkedExpense(expenseId).getSingleOrNull())?.id;
      if (owner != null && owner != billId) {
        throw const KobanUserError(
          'This payment already belongs to another split.',
        );
      }
    }
    if (oldId != null && oldId != expenseId) {
      await _setCounted(oldId, null);
    }
    if (oldId != expenseId) {
      await _insertBill(bill.copyWith(linkedExpenseId: Value(expenseId)));
    }
    if (expenseId != null) await _recomputeCounted(billId, expenseId);
  }

  Future<void> _recomputeCounted(String billId, String expenseId) async {
    final expense = await _db.expenseById(expenseId).getSingleOrNull();
    if (expense == null) return;
    final owed = _sum((await _db.debts(billId).get()).map((d) => d.amount));
    await _updateExpense(
      expense.copyWith(
        countedAmount: Value(SplitMath.ownerSpending(expense.amount, owed)),
      ),
    );
  }

  Future<void> onExpenseEdited(String expenseId) => _db.transaction(() async {
    final bill = await billForExpense(expenseId);
    if (bill != null) await _recomputeCounted(bill.id, expenseId);
  });

  Future<void> deleteSplit(String billId) => _db.transaction(() async {
    final bill = await _db.bill(billId).getSingleOrNull();
    if (bill == null) return;
    final debts = await _db.debts(billId).get();
    final repaymentIds = [
      for (final d in debts)
        if (d.repaymentExpenseId != null) d.repaymentExpenseId!,
    ];
    await _db.deleteSharesByBill(billId);
    await _db.deleteItemsByBill(billId);
    await _db.deleteDebtsByBill(billId);
    for (final id in {
      for (final d in debts)
        if (d.status == DebtStatus.open) d.personId,
    }) {
      await clearSettleSuggestion(id);
    }
    await _db.deleteBill(billId);
    // A repayment that still pays a debt in another bill stays used.
    final freed = <String>[];
    for (final id in repaymentIds) {
      if ((await _db.debtsByRepayment(id).get()).isEmpty) freed.add(id);
    }
    for (final id in {
      if (bill.linkedExpenseId != null) bill.linkedExpenseId!,
      ...freed,
    }) {
      await _setCounted(id, null);
    }
  });

  /// Unlinked withdrawals within 3 days of the bill: exact-amount ones first, newest first.
  Future<List<Expense>> paymentCandidates(
    String? billId,
    Decimal total,
    int billTime,
  ) async {
    final recent = await _db
        .recentByType(TransactionType.withdraw, billTime - _paymentWindowMs)
        .get();
    final free = <Expense>[];
    for (final e in recent) {
      if (e.notificationPostTime > billTime + _paymentWindowMs) continue;
      final b = await billForExpense(e.id);
      if (b == null || b.id == billId) free.add(e);
    }
    return [
      ...free.where((e) => e.amount.compareTo(total) == 0),
      ...free.where((e) => e.amount.compareTo(total) != 0),
    ];
  }

  Future<List<Expense>> repaymentCandidates(String debtId) async {
    final debt = await _db.debt(debtId).getSingleOrNull();
    if (debt == null) return const [];
    final bill = await _db.bill(debt.billId).getSingleOrNull();
    if (bill == null) return const [];
    final personOpen = _sum(
      (await _db.openDebts().get())
          .where((d) => d.personId == debt.personId)
          .map((d) => d.amount),
    );
    final recent = await _db
        .recentByType(TransactionType.receive, bill.billTime - _repaymentLeadMs)
        .get();
    return [
      for (final e in recent)
        if (e.amount.compareTo(debt.amount) == 0 ||
            e.amount.compareTo(personOpen) == 0)
          e,
    ];
  }

  Future<void> markPaid(
    String debtId,
    String? repaymentExpenseId,
  ) => _db.transaction(() async {
    final debt = await _db.debt(debtId).getSingleOrNull();
    if (debt == null) return;
    if (debt.status == DebtStatus.paid) return;
    if (repaymentExpenseId == null) {
      await _close([debt], null);
      return;
    }
    final expense = await _db.expenseById(repaymentExpenseId).getSingleOrNull();
    if (expense == null || !isUsableRepayment(expense)) {
      throw const KobanUserError('Repayment expense is not available');
    }
    final personOpen = (await _db.openDebts().get())
        .where((d) => d.personId == debt.personId)
        .toList();
    final total = _sum(personOpen.map((d) => d.amount));
    final List<SplitDebt> closing;
    if (expense.amount.compareTo(total) == 0) {
      closing = personOpen;
    } else if (expense.amount.compareTo(debt.amount) == 0) {
      closing = [debt];
    } else {
      throw const KobanUserError('Repayment amount does not match this debt');
    }
    await _close(closing, expense);
  });

  Future<void> confirmSuggestion(String debtId) => _db.transaction(() async {
    final expenseId =
        (await _db.debt(debtId).getSingleOrNull())?.suggestedRepaymentExpenseId;
    if (expenseId == null) return;
    final debts = await _suggestedWith(expenseId);
    final expense = await _db.expenseById(expenseId).getSingleOrNull();
    final owed = _sum(debts.map((d) => d.amount));
    if (expense == null ||
        !isUsableRepayment(expense) ||
        expense.amount.compareTo(owed) != 0) {
      // Stale suggestion: the receive changed or was used. Clear it, do not close.
      for (final d in debts) {
        await _updateDebt(
          d.copyWith(suggestedRepaymentExpenseId: const Value(null)),
        );
      }
      return;
    }
    await _close(debts, expense);
  });

  bool isUsableRepayment(Expense e) =>
      e.transactionType == TransactionType.receive &&
      e.status != ExpenseStatus.dismissed &&
      e.countedAmount == null;

  Future<void> dismissSuggestion(String debtId) => _db.transaction(() async {
    final expenseId =
        (await _db.debt(debtId).getSingleOrNull())?.suggestedRepaymentExpenseId;
    if (expenseId == null) return;
    for (final d in await _suggestedWith(expenseId)) {
      await _updateDebt(
        d.copyWith(suggestedRepaymentExpenseId: const Value(null)),
      );
    }
  });

  Future<List<SplitDebt>> _suggestedWith(String expenseId) async =>
      (await _db.openDebts().get())
          .where((d) => d.suggestedRepaymentExpenseId == expenseId)
          .toList();

  /// Closes every open debt of [personId]. A non-null [expense] is marked used even when no debt is open.
  Future<void> closeAllFor(String personId, Expense? expense) =>
      _db.transaction(() async {
        await _close(await _db.openDebtsFor(personId).get(), expense);
        await clearSettleSuggestion(personId);
      });

  Future<void> clearSettleSuggestion(String personId) async {
    final person = await _db.person(personId).getSingleOrNull();
    if (person == null) return;
    if (person.suggestedSettleExpenseId == null) return;
    await _upsertPerson(
      person.copyWith(suggestedSettleExpenseId: const Value(null)),
    );
  }

  /// Marks [debts] PAID. A null [expense] means cash.
  Future<void> _close(List<SplitDebt> debts, Expense? expense) async {
    final now = _now();
    // A settle suggestion goes stale when its person's debts change or its expense gets used.
    final personIds = {for (final d in debts) d.personId};
    for (final p in await _db.allPeopleIncludingArchived().get()) {
      if (p.suggestedSettleExpenseId == null) continue;
      if (personIds.contains(p.id) ||
          (expense != null && p.suggestedSettleExpenseId == expense.id)) {
        await _upsertPerson(
          p.copyWith(suggestedSettleExpenseId: const Value(null)),
        );
      }
    }
    // Other open debts must not keep a suggestion that this close made stale.
    final staleIds = {
      for (final d in debts)
        if (d.suggestedRepaymentExpenseId != null)
          d.suggestedRepaymentExpenseId!,
      if (expense != null) expense.id,
    };
    final closingIds = {for (final d in debts) d.id};
    for (final d in await _db.openDebts().get()) {
      if (!closingIds.contains(d.id) &&
          staleIds.contains(d.suggestedRepaymentExpenseId)) {
        await _updateDebt(
          d.copyWith(suggestedRepaymentExpenseId: const Value(null)),
        );
      }
    }
    for (final d in debts) {
      await _updateDebt(
        d.copyWith(
          status: DebtStatus.paid,
          repaymentExpenseId: Value(expense?.id),
          suggestedRepaymentExpenseId: const Value(null),
          paidAt: Value(now),
        ),
      );
    }
    // Zero marks the receive as used so it is not offered again. Totals count spending only.
    if (expense != null) {
      await _updateExpense(expense.copyWith(countedAmount: Value(_zeroMoney)));
    }
  }

  Future<void> suggestRepayment(Expense receive) async {
    if (receive.transactionType != TransactionType.receive) return;
    await _db.transaction(() async {
      final allOpen = await _db.openDebts().get();
      final open = allOpen
          .where((d) => d.suggestedRepaymentExpenseId == null)
          .toList();
      final people = await _db.allPeopleIncludingArchived().get();
      final names = {for (final p in people) p.id: p.name};
      final billTimes = <String, int>{};
      for (final id in {for (final d in open) d.billId}) {
        billTimes[id] =
            (await _db.bill(id).getSingleOrNull())?.billTime ?? _maxLong;
      }
      // Oldest bill first. List.sort is not stable, so the index breaks ties.
      final indexed = [for (var i = 0; i < open.length; i++) (i, open[i])]
        ..sort((a, b) {
          final c = billTimes[a.$2.billId]!.compareTo(billTimes[b.$2.billId]!);
          return c != 0 ? c : a.$1.compareTo(b.$1);
        });
      final refs = [
        for (final (_, d) in indexed)
          OpenDebtRef(
            debtId: d.id,
            personId: d.personId,
            personName: names[d.personId] ?? '',
            amount: d.amount,
          ),
      ];
      final matched = RepaymentMatcher.match(
        receive.amount,
        receive.merchant,
        refs,
      ).toSet();
      for (final d in open.where((d) => matched.contains(d.id))) {
        await _updateDebt(
          d.copyWith(suggestedRepaymentExpenseId: Value(receive.id)),
        );
      }
      if (matched.isNotEmpty) return;

      // No subset of debts fits: offer a settle up to the one person whose whole net equals the amount.
      final debtsByPerson = <String, List<SplitDebt>>{};
      for (final d in allOpen) {
        (debtsByPerson[d.personId] ??= []).add(d);
      }
      final candidates = <SettleCandidate>[];
      for (final p in people) {
        if (p.archived ||
            p.suggestedSettleExpenseId != null ||
            !debtsByPerson.containsKey(p.id)) {
          continue;
        }
        candidates.add(
          SettleCandidate(
            p.id,
            p.name,
            PeopleMath.net(
              debtsByPerson[p.id]!.map((d) => d.amount).toList(),
              (await _db.openOwedItems(p.id).get())
                  .map((o) => o.amount)
                  .toList(),
            ),
          ),
        );
      }
      final personId = PeopleMath.settleMatch(
        receive.amount,
        receive.merchant,
        candidates,
      );
      if (personId == null) return;
      final person = people.firstWhere((p) => p.id == personId);
      await _upsertPerson(
        person.copyWith(suggestedSettleExpenseId: Value(receive.id)),
      );
    });
  }

  // Kotlin Long.MAX_VALUE. A bill that is gone sorts last.
  static const _maxLong = 9223372036854775807;

  // Writes. They copy the Room @Insert(REPLACE) and @Update methods.

  Future<void> _upsertPerson(SplitPeopleData p) =>
      _db.into(_db.splitPeople).insert(p, mode: InsertMode.insertOrReplace);

  Future<void> _insertBill(SplitBill b) =>
      _db.into(_db.splitBills).insert(b, mode: InsertMode.insertOrReplace);

  Future<void> _updateDebt(SplitDebt d) =>
      _db.update(_db.splitDebts).replace(d);

  Future<void> _updateExpense(Expense e) => _db.update(_db.expenses).replace(e);

  /// Sets the counted amount of an expense. A missing expense is skipped.
  Future<void> _setCounted(String id, Decimal? counted) async {
    final e = await _db.expenseById(id).getSingleOrNull();
    if (e != null) {
      await _updateExpense(e.copyWith(countedAmount: Value(counted)));
    }
  }
}
