import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../rules/amount_formatter.dart';
import '../rules/people_math.dart';
import '../rules/types.dart';
import 'database.dart';
import 'ids.dart';
import 'qr_store.dart';
import 'split_repository.dart';
import 'undoable.dart';
import 'user_error.dart';
import 'watch.dart';

/// One row of the people list.
class PersonSummary {
  const PersonSummary({
    required this.person,
    required this.balance,
    required this.hasOpen,
  });

  final SplitPeopleData person;
  final Balance balance;

  /// True when an open debt or an open owed item exists.
  final bool hasOpen;
}

/// All that the person page shows.
class PersonDetail {
  const PersonDetail({
    required this.person,
    required this.balance,
    required this.owedToMe,
    required this.iOwe,
    required this.settleSuggestion,
  });

  final SplitPeopleData person;
  final Balance balance;
  final List<OpenDebtView> owedToMe;
  final List<OwedItem> iOwe;

  /// The received payment that can settle up with the person, or null.
  final Expense? settleSuggestion;
}

/// The contact book: people, what is open both ways, their QR, and settling up.
/// A port of `PeopleRepository.kt`.
class PeopleRepository {
  PeopleRepository(
    this._db, {
    required this._splits,
    required this._qr,
    required this._now,
  });

  final KobanDatabase _db;
  final SplitRepository _splits;
  final QrStore _qr;
  final int Function() _now;

  Stream<List<PersonSummary>> watchPeople() => watchTables(
    _db,
    {_db.splitPeople, _db.splitDebts, _db.owedItems},
    () async {
      final people = await _db.allPeople().get();
      final owedByPerson = <String, List<Decimal>>{};
      for (final d in await _db.openDebts().get()) {
        (owedByPerson[d.personId] ??= []).add(d.amount);
      }
      final iOweByPerson = <String, List<Decimal>>{};
      for (final i in await _db.allOpenOwedItems().get()) {
        (iOweByPerson[i.personId] ??= []).add(i.amount);
      }
      return [
        for (final person in people)
          PersonSummary(
            person: person,
            balance: PeopleMath.balance(
              owedByPerson[person.id] ?? const [],
              iOweByPerson[person.id] ?? const [],
            ),
            hasOpen:
                (owedByPerson[person.id] ?? const []).isNotEmpty ||
                (iOweByPerson[person.id] ?? const []).isNotEmpty,
          ),
      ];
    },
  );

  /// Emits null when the person is missing or archived.
  Stream<PersonDetail?> watchPerson(String personId) => watchTables(
    _db,
    {
      _db.splitPeople,
      _db.splitDebts,
      _db.splitBills,
      _db.owedItems,
      _db.expenses,
    },
    () async {
      final person = await _db.person(personId).getSingleOrNull();
      if (person == null || person.archived) return null;
      final debts = [
        for (final v in await _splits.watchOpenDebts().first)
          if (v.debt.personId == personId) v,
      ];
      final items = await _db.owedItemsOf(personId).get();
      final suggestedId = person.suggestedSettleExpenseId;
      return PersonDetail(
        person: person,
        balance: PeopleMath.balance(
          [for (final v in debts) v.debt.amount],
          [for (final i in items) i.amount],
        ),
        owedToMe: debts,
        iOwe: items,
        settleSuggestion: suggestedId == null
            ? null
            : await _db.expenseById(suggestedId).getSingleOrNull(),
      );
    },
  );

  /// Returns the id of the person with this name, revives an archived one, or makes a new person.
  Future<String> addPerson(String name) => _db.transaction(() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const KobanUserError('Enter a name.');
    final now = _now();
    final key = PeopleMath.normalizedName(trimmed);
    // Active people come first, so an active match wins over an archived one.
    final all = await _db.allPeopleIncludingArchived().get();
    all.sort((a, b) => (a.archived ? 1 : 0) - (b.archived ? 1 : 0));
    final match = all
        .where((p) => PeopleMath.normalizedName(p.name) == key)
        .firstOrNull;
    if (match == null) {
      final person = SplitPeopleData(
        id: newId(),
        name: trimmed,
        lastUsedAt: now,
        archived: false,
      );
      await _upsertPerson(person);
      return person.id;
    }
    if (match.archived) {
      await _upsertPerson(match.copyWith(archived: false, lastUsedAt: now));
    }
    return match.id;
  });

  Future<void> renamePerson(String personId, String name) =>
      _db.transaction(() async {
        final trimmed = name.trim();
        if (trimmed.isEmpty) throw const KobanUserError('Enter a name.');
        final person = await _db.person(personId).getSingleOrNull();
        if (person == null) return;
        final key = PeopleMath.normalizedName(trimmed);
        final taken = (await _db.people().get()).any(
          (p) => p.id != personId && PeopleMath.normalizedName(p.name) == key,
        );
        if (taken) throw const KobanUserError('Someone already has that name.');
        await _upsertPerson(person.copyWith(name: trimmed));
      });

  /// Archives a person with nothing open. It deletes the paid items and the QR file.
  /// Undo puts back the person row, the paid items and the QR file. It returns null
  /// when the person is missing.
  Future<Undoable?> archivePerson(String personId) async {
    final snapshot = await _db.transaction(() async {
      final person = await _db.person(personId).getSingleOrNull();
      if (person == null) return null;
      if ((await _db.openDebtsFor(personId).get()).isNotEmpty ||
          (await _db.openOwedItems(personId).get()).isNotEmpty) {
        throw const KobanUserError('Settle up with them first.');
      }
      final paid = [
        for (final i in await (_db.select(
          _db.owedItems,
        )..where((t) => t.personId.equals(personId))).get())
          if (i.status == DebtStatus.paid) i,
      ];
      // Read the picture before the row stops pointing at it.
      final qr = await _qr.read(person.qrPath);
      await _db.deletePaidOwedItems(personId);
      await _upsertPerson(
        person.copyWith(
          archived: true,
          qrPath: const Value(null),
          suggestedSettleExpenseId: const Value(null),
        ),
      );
      return (person, paid, qr);
    });
    if (snapshot == null) return null;
    final (person, paid, qr) = snapshot;
    // Delete the file only after the row no longer points at it.
    await _qr.delete(person.qrPath);
    return Undoable(
      undo: () async {
        var replaced = false;
        await _db.transaction(() async {
          final now = await _db.person(personId).getSingleOrNull();
          // Added again by name in the meantime: that row has the person already,
          // and it does not point to the old QR file.
          replaced = now != null && !now.archived;
          if (!replaced) await _upsertPerson(person);
          for (final i in paid) {
            await _db
                .into(_db.owedItems)
                .insert(i, mode: InsertMode.insertOrReplace);
          }
        });
        if (!replaced && person.qrPath != null && qr != null) {
          await _qr.restore(person.qrPath!, qr);
        }
      },
    );
  }

  /// Copies the picture at [sourcePath] as the QR of the person.
  Future<void> setQr(String personId, String sourcePath) async {
    if (await _db.person(personId).getSingleOrNull() == null) return;
    final path = await _qr.importQr(personId, sourcePath);
    await _db.transaction(() async {
      final person = await _db.person(personId).getSingleOrNull();
      if (person == null) return;
      await _upsertPerson(person.copyWith(qrPath: Value(path)));
    });
  }

  Future<void> saveQrToGallery(String personId) async {
    final person = await _db.person(personId).getSingleOrNull();
    final path = person?.qrPath;
    if (person == null || path == null) {
      throw const KobanUserError('No QR saved yet');
    }
    final safe = person.name.replaceAll(
      RegExp(r'[^\p{L}\p{N}]', unicode: true),
      '-',
    );
    await _qr.saveToGallery(path, 'koban-$safe-qr.jpg');
  }

  Future<void> addOwedItem(
    String personId,
    String description,
    Decimal amount,
    int itemDate,
  ) async {
    _validate(description, amount);
    await _db.transaction(() async {
      await _db
          .into(_db.owedItems)
          .insert(
            OwedItem(
              id: newId(),
              personId: personId,
              description: description.trim(),
              amount: AmountFormatter.toMoney(amount),
              itemDate: itemDate,
              createdAt: _now(),
              status: DebtStatus.open,
            ),
            mode: InsertMode.insertOrReplace,
          );
      await _splits.clearSettleSuggestion(personId);
    });
  }

  Future<void> updateOwedItem(OwedItem item) async {
    _validate(item.description, item.amount);
    await _db.transaction(() async {
      await _db
          .update(_db.owedItems)
          .replace(
            item.copyWith(
              description: item.description.trim(),
              amount: AmountFormatter.toMoney(item.amount),
            ),
          );
      await _splits.clearSettleSuggestion(item.personId);
    });
  }

  /// Undo puts the item back, and the repayment suggestion that the delete cleared.
  Future<Undoable?> deleteOwedItem(String id) => _db.transaction(() async {
    final item = await _db.owedItem(id).getSingleOrNull();
    if (item == null) return null;
    final suggested = (await _db.person(item.personId).getSingleOrNull())
        ?.suggestedSettleExpenseId;
    await _db.deleteOwedItem(id);
    await _splits.clearSettleSuggestion(item.personId);
    return Undoable(
      undo: () => _db.transaction(() async {
        await _db
            .into(_db.owedItems)
            .insert(item, mode: InsertMode.insertOrReplace);
        // An open item of an archived person shows nowhere.
        final owner = await _db.person(item.personId).getSingleOrNull();
        if (item.status == DebtStatus.open && owner != null && owner.archived) {
          await _upsertPerson(owner.copyWith(archived: false));
        }
        await _splits.restoreSettleSuggestion(item.personId, suggested);
      }),
    );
  });

  Future<void> markOwedItemPaid(String id) => _db.transaction(() async {
    final item = await _db.owedItem(id).getSingleOrNull();
    if (item == null || item.status == DebtStatus.paid) return;
    await _db
        .update(_db.owedItems)
        .replace(item.copyWith(status: DebtStatus.paid, paidAt: Value(_now())));
    await _splits.clearSettleSuggestion(item.personId);
  });

  /// Adds money that [personId] owes the owner without a bill, for example cash lent.
  /// It is a manual split bill with one debt. Repayment matching, Mark paid
  /// and Settle up treat it as any debt.
  Future<void> addOwedToMe(
    String personId,
    String description,
    Decimal amount,
    int itemDate,
  ) async {
    _validate(description, amount);
    await _db.transaction(() async {
      final billId = newId();
      final zero = AmountFormatter.toMoney(Decimal.zero);
      await _db
          .into(_db.splitBills)
          .insert(
            SplitBill(
              id: billId,
              merchant: description.trim(),
              billTime: itemDate,
              currency: 'MYR',
              serviceCharge: zero,
              tax: zero,
              discount: zero,
              rounding: zero,
              createdAt: _now(),
              manual: true,
            ),
            mode: InsertMode.insertOrReplace,
          );
      await _db
          .into(_db.splitDebts)
          .insert(
            SplitDebt(
              id: newId(),
              billId: billId,
              personId: personId,
              amount: AmountFormatter.toMoney(amount),
              status: DebtStatus.open,
            ),
            mode: InsertMode.insertOrReplace,
          );
      await _splits.clearSettleSuggestion(personId);
    });
  }

  /// Edits an open hand-added debt. A repayment suggestion that included it is dropped.
  Future<void> updateOwedToMe(
    String debtId,
    String description,
    Decimal amount,
    int itemDate,
  ) async {
    _validate(description, amount);
    await _db.transaction(() async {
      final found = await _openManualDebt(debtId);
      if (found == null) return;
      final (debt, bill) = found;
      await _db
          .into(_db.splitBills)
          .insert(
            bill.copyWith(
              merchant: Value(description.trim()),
              billTime: itemDate,
            ),
            mode: InsertMode.insertOrReplace,
          );
      final stale = debt.suggestedRepaymentExpenseId;
      if (stale != null) {
        for (final d in await _db.openDebts().get()) {
          if (d.suggestedRepaymentExpenseId == stale) {
            await _updateDebt(
              d.copyWith(suggestedRepaymentExpenseId: const Value(null)),
            );
          }
        }
      }
      await _updateDebt(
        debt.copyWith(
          amount: AmountFormatter.toMoney(amount),
          suggestedRepaymentExpenseId: const Value(null),
        ),
      );
      await _splits.clearSettleSuggestion(debt.personId);
    });
  }

  /// Deletes the hand-added debt with its bill. Undo restores both.
  Future<Undoable?> deleteOwedToMe(String debtId) async {
    final billId = await _db.transaction(
      () async => (await _openManualDebt(debtId))?.$2.id,
    );
    if (billId == null) return null;
    return _splits.deleteSplit(billId);
  }

  Future<(SplitDebt, SplitBill)?> _openManualDebt(String debtId) async {
    final debt = await _db.debt(debtId).getSingleOrNull();
    if (debt == null) return null;
    final bill = await _db.bill(debt.billId).getSingleOrNull();
    if (bill == null) return null;
    return bill.manual && debt.status == DebtStatus.open ? (debt, bill) : null;
  }

  Future<void> settleUp(String personId) =>
      _db.transaction(() => _settle(personId, null));

  /// Settles up with the suggested received payment linked. It returns false and closes
  /// nothing when no suggestion exists or it is stale (the payment changed, was used,
  /// or the net moved). A stale suggestion is cleared.
  Future<bool> confirmSettleSuggestion(String personId) =>
      _db.transaction(() async {
        final person = await _db.person(personId).getSingleOrNull();
        final expenseId = person?.suggestedSettleExpenseId;
        if (expenseId == null) return false;
        final expense = await _db.expenseById(expenseId).getSingleOrNull();
        final net = PeopleMath.net(
          [for (final d in await _db.openDebtsFor(personId).get()) d.amount],
          [for (final i in await _db.openOwedItems(personId).get()) i.amount],
        );
        if (expense == null ||
            !_splits.isUsableRepayment(expense) ||
            expense.amount.compareTo(net) != 0) {
          await _splits.clearSettleSuggestion(personId);
          return false;
        }
        await _settle(personId, expense);
        return true;
      });

  Future<void> dismissSettleSuggestion(String personId) =>
      _db.transaction(() => _splits.clearSettleSuggestion(personId));

  /// Closes all that is open for [personId]. Only split debts get the [expense] link.
  /// Call it inside a transaction.
  Future<void> _settle(String personId, Expense? expense) async {
    await _splits.closeAllFor(personId, expense);
    final now = _now();
    for (final i in await _db.openOwedItems(personId).get()) {
      await _db
          .update(_db.owedItems)
          .replace(i.copyWith(status: DebtStatus.paid, paidAt: Value(now)));
    }
  }

  void _validate(String description, Decimal amount) {
    if (description.trim().isEmpty) {
      throw const KobanUserError('Enter what it was for.');
    }
    if (amount.sign <= 0) {
      throw const KobanUserError('Enter an amount above zero.');
    }
  }

  Future<void> _upsertPerson(SplitPeopleData p) =>
      _db.into(_db.splitPeople).insert(p, mode: InsertMode.insertOrReplace);

  Future<void> _updateDebt(SplitDebt d) =>
      _db.update(_db.splitDebts).replace(d);
}
