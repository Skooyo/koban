import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../rules/amount_formatter.dart';
import '../rules/periods.dart';
import '../rules/types.dart';
import 'category_repository.dart';
import 'database.dart';
import 'expense_dedup.dart';
import 'ids.dart';
import 'merchant_category_repository.dart';
import 'split_repository.dart';
import 'summaries.dart';
import 'undoable.dart';
import 'watch.dart';

const _recentInPeriod = 5;

String? _blankToNull(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The payments the owner sees. A port of `ExpenseRepository.kt`.
class ExpenseRepository {
  ExpenseRepository(
    this._db, {
    required this._categories,
    required this._merchants,
    required this._splits,
    required this._now,
  });

  static const manualSource = 'manual';

  final KobanDatabase _db;
  final CategoryRepository _categories;
  final MerchantCategoryRepository _merchants;
  final SplitRepository _splits;
  final DateTime Function() _now;

  /// True when one payment shows in Activity. Dismissed payments do not count.
  Stream<bool> watchHasAnyPayment() => _db.anyExpense().watchSingle();

  Stream<List<Expense>> watchAllActive() => _db.allActive().watch();

  Stream<Decimal> watchTotalForRange(int start, int end) =>
      _db.totalForRange(start, end).watchSingle();

  /// Money received in the range. It shows beside spending and is never subtracted from it.
  Stream<Decimal> watchReceivedForRange(int start, int end) =>
      _db.receivedForRange(start, end).watchSingle();

  Stream<List<Expense>> watchInRange(int start, int end) =>
      _db.inRange(start, end).watch();

  Stream<List<MonthSummary>> watchMonthlySummaries() =>
      _db.monthlyTotals().watch().map((rows) {
        return [
          for (final row in rows)
            _monthSummary(row.yearMonth, row.total, row.received),
        ];
      });

  MonthSummary _monthSummary(int yearMonth, Decimal total, Decimal received) {
    final (year, month0) = PeriodCalculator.decodeYearMonth(yearMonth);
    return MonthSummary(
      year: year,
      month0: month0,
      label: PeriodCalculator.monthLabel(year, month0),
      total: total,
      received: received,
    );
  }

  /// The weeks of a month with their totals, cut to the days of the month. [month0] is 0-based.
  Future<List<WeekSummary>> weekSummariesForMonth(int year, int month0) async {
    final weeks = <WeekSummary>[];
    for (final (start, end) in PeriodCalculator.weeksInMonth(year, month0)) {
      weeks.add(
        WeekSummary(
          startMs: start,
          endMs: end,
          label: PeriodCalculator.daysLabel(start, end),
          total: await _db.totalForRangeOnce(start, end).getSingle(),
        ),
      );
    }
    return weeks;
  }

  /// The day, week or month that holds the time of `now` when this method runs.
  Stream<PeriodSummary> watchPeriodSummary(SpendingPeriod period) {
    final anchor = _now();
    final (start, end) = PeriodCalculator.range(period, anchor: anchor);
    return watchTables(_db, {_db.expenses, _db.categories}, () async {
      final expenses = await _db.inRange(start, end).get();
      return PeriodSummary(
        title: PeriodCalculator.title(period),
        subtitle: PeriodCalculator.label(period, anchor: anchor),
        total: await _db.totalForRange(start, end).getSingle(),
        breakdown: await _breakdown(start, end),
        recentExpenses: expenses.take(_recentInPeriod).toList(),
        periodStart: start,
        periodEnd: end,
        received: await _db.receivedForRange(start, end).getSingle(),
      );
    });
  }

  Stream<List<CategoryBreakdown>> watchCategoryBreakdown(int start, int end) =>
      watchTables(_db, {
        _db.expenses,
        _db.categories,
      }, () => _breakdown(start, end));

  Future<List<CategoryBreakdown>> _breakdown(int start, int end) async {
    final rows = await _db.totalsByCategory(start, end).get();
    final byId = {for (final c in await _categories.getAll()) c.id: c};
    final absSum = rows.fold(Decimal.zero, (sum, r) => sum + r.total.abs());
    return [
      for (final row in rows)
        CategoryBreakdown(
          categoryId: row.categoryId,
          name:
              byId[row.categoryId]?.name ??
              CategoryRepository.uncategorizedName,
          colorHex:
              byId[row.categoryId]?.colorHex ??
              CategoryRepository.uncategorizedColor,
          total: row.total,
          count: row.spentCount ?? 0,
          // Round half up to 4 decimals, as Kotlin divide(absSum, 4, HALF_UP).
          fraction: absSum > Decimal.zero
              ? (row.total.abs() * Decimal.fromInt(10000) / absSum)
                        .round()
                        .toInt() /
                    10000
              : 0,
        ),
    ];
  }

  Future<Expense?> getById(String id) => _db.expenseById(id).getSingleOrNull();

  /// Saves a waiting payment that the owner confirmed, with the values of the card.
  /// Returns false when a payment already covers it. One transaction, so a
  /// capture of another connection cannot race the duplicate check.
  Future<bool> saveConfirmed(PendingPayment p) => _db.transaction(() async {
    final amount = AmountFormatter.toMoney(p.amount);
    final duplicate =
        !p.dedupKey.startsWith(forcedDedupPrefix) &&
        await _db.hasExpenseFor(
          amount: amount,
          transactionType: p.transactionType,
          merchant: p.merchant,
          postTime: p.notificationPostTime,
          dedupKey: p.dedupKey,
          notificationKey: p.notificationKey,
        );
    if (duplicate) return false;

    // The category of the card wins over the merchant memory.
    final categoryId =
        p.categoryId ?? await _merchants.categoryIdForMerchant(p.merchant);
    final expense = Expense(
      id: newId(),
      amount: amount,
      currency: p.currency,
      merchant: p.merchant,
      rawNotificationText: p.rawNotificationText,
      sourcePackage: p.sourcePackage,
      notificationPostTime: p.notificationPostTime,
      createdAt: _now().millisecondsSinceEpoch,
      dedupKey: p.dedupKey,
      status: p.edited ? ExpenseStatus.edited : ExpenseStatus.autoSaved,
      // The owner checked this payment.
      confidence: ParseConfidence.high,
      notificationKey: p.notificationKey,
      categoryId: categoryId,
      transactionType: p.transactionType,
      privateToGroups: false,
    );
    // A new id cannot conflict, so the insert always adds the row.
    await _db.into(_db.expenses).insert(expense);
    if (p.edited) await _merchants.saveMapping(p.merchant, categoryId);
    if (expense.transactionType == TransactionType.receive) {
      try {
        await _splits.suggestRepayment(expense);
      } catch (e, s) {
        developer.log(
          'Repayment suggestion failed',
          name: 'ExpenseRepository',
          error: e,
          stackTrace: s,
        );
      }
    }
    return true;
  });

  /// Saves the edit. A new category also changes the past payments from the shop, unless
  /// [applyToPast] is false. Returns an Undo for that change, or null when no past payment changed.
  Future<Undoable?> updateExpense(
    String id, {
    required Decimal amount,
    String? merchant,
    required int postTime,
    String? categoryId,
    String? notes,
    required TransactionType type,
    bool privateToGroups = false,
    bool applyToPast = true,
  }) async {
    final existing = await getById(id);
    if (existing == null) return null;
    // A new category applies to every payment from this shop in the same direction, past ones included.
    final undo = await _rememberShop(
      merchant,
      type,
      categoryId,
      applyToPast: applyToPast && categoryId != existing.categoryId,
      excludeId: id,
    );
    await _db
        .update(_db.expenses)
        .replace(
          existing.copyWith(
            amount: AmountFormatter.toMoney(amount),
            merchant: Value(merchant),
            notificationPostTime: postTime,
            categoryId: Value(categoryId),
            notes: Value(_blankToNull(notes)),
            transactionType: type,
            privateToGroups: privateToGroups,
            status: ExpenseStatus.edited,
          ),
        );
    try {
      await _splits.onExpenseEdited(id);
    } catch (e, s) {
      developer.log(
        'Split recompute failed',
        name: 'ExpenseRepository',
        error: e,
        stackTrace: s,
      );
    }
    return undo;
  }

  /// A payment that the owner types in, for one that came without a readable notification.
  /// Returns its id, and an Undo for the change of past payments from the shop, if any.
  Future<({String id, Undoable? undo})> addManualExpense({
    required Decimal amount,
    String? merchant,
    required int postTime,
    String? categoryId,
    String? notes,
    required TransactionType type,
    bool privateToGroups = false,
    bool applyToPast = true,
  }) async {
    final id = newId();
    final undo = await _rememberShop(
      merchant,
      type,
      categoryId,
      applyToPast: applyToPast,
      excludeId: id,
    );
    final expense = Expense(
      id: id,
      amount: AmountFormatter.toMoney(amount),
      currency: 'MYR',
      merchant: _blankToNull(merchant),
      rawNotificationText: '',
      sourcePackage: manualSource,
      notificationPostTime: postTime,
      createdAt: _now().millisecondsSinceEpoch,
      dedupKey: 'manual:$id',
      status: ExpenseStatus.edited,
      confidence: ParseConfidence.high,
      categoryId: categoryId,
      notes: _blankToNull(notes),
      transactionType: type,
      privateToGroups: privateToGroups,
    );
    await _db
        .into(_db.expenses)
        .insert(expense, mode: InsertMode.insertOrIgnore);
    if (type == TransactionType.receive) {
      try {
        await _splits.suggestRepayment(expense);
      } catch (e, s) {
        developer.log(
          'Repayment suggestion failed',
          name: 'ExpenseRepository',
          error: e,
          stackTrace: s,
        );
      }
    }
    return (id: id, undo: undo);
  }

  /// Hides the payment from every total. The row and its split links stay.
  /// Undo sets the status the payment had. It returns null when the payment is missing.
  Future<Undoable?> dismissExpense(String id) async {
    final existing = await getById(id);
    if (existing == null) return null;
    await _db
        .update(_db.expenses)
        .replace(existing.copyWith(status: ExpenseStatus.dismissed));
    return Undoable(
      undo: () => _db.transaction(() async {
        final now = await getById(id);
        if (now == null || now.status != ExpenseStatus.dismissed) return;
        await _db
            .update(_db.expenses)
            .replace(now.copyWith(status: existing.status));
      }),
    );
  }

  /// How many past payments from the shop a change to [categoryId] would change.
  Future<int> countPastForShop(
    String? merchant,
    TransactionType type,
    String categoryId, {
    String? excludeId,
  }) async => (await _pastRows(merchant, type, categoryId, excludeId)).length;

  // ponytail: SQLite lower() folds ASCII letters only, so a shop with non-ASCII capitals can be missed.
  // Upgrade: store the normalized key in its own column.
  /// The payments from the shop, in the same direction, that a change to [categoryId] would change.
  /// Dismissed payments stay out, so the count the owner sees is the count that changes.
  Future<List<({String id, String? categoryId})>> _pastRows(
    String? merchant,
    TransactionType type,
    String categoryId,
    String? excludeId,
  ) async {
    final key = _merchants.normalizeKey(merchant);
    if (key == null) return const [];
    final rows = await _db
        .customSelect(
          'SELECT id, categoryId FROM expenses '
          "WHERE lower(trim(merchant)) = ? AND transactionType = ? AND status != 'DISMISSED' "
          "AND id != ? AND COALESCE(categoryId, '') != ?",
          variables: [
            Variable<String>(key),
            Variable<String>(type.dbName),
            Variable<String>(excludeId ?? ''),
            Variable<String>(categoryId),
          ],
          readsFrom: {_db.expenses},
        )
        .get();
    return [
      for (final r in rows)
        (
          id: r.read<String>('id'),
          categoryId: r.readNullable<String>('categoryId'),
        ),
    ];
  }

  /// Remembers the category of the shop, and changes its past payments when [applyToPast].
  /// The Undo puts the past payments and the shop's mapping back as they were.
  /// It is null when no past payment changed.
  Future<Undoable?> _rememberShop(
    String? merchant,
    TransactionType type,
    String? categoryId, {
    required bool applyToPast,
    required String excludeId,
  }) async {
    final key = _merchants.normalizeKey(merchant);
    final before = key == null
        ? null
        : await _db.merchantMappingByKey(key).getSingleOrNull();
    await _merchants.saveMapping(merchant, categoryId);
    if (key == null || categoryId == null || !applyToPast) return null;
    final rows = await _pastRows(merchant, type, categoryId, excludeId);
    if (rows.isEmpty) return null;
    await _db.transaction(() async {
      for (final r in rows) {
        await _setCategory(r.id, categoryId);
      }
    });
    return Undoable(
      undo: () => _db.transaction(() async {
        for (final r in rows) {
          await _setCategory(r.id, r.categoryId);
        }
        if (before == null) {
          await (_db.delete(
            _db.merchantCategoryMap,
          )..where((m) => m.merchantKey.equals(key))).go();
        } else {
          await _db
              .into(_db.merchantCategoryMap)
              .insert(before, mode: InsertMode.insertOrReplace);
        }
      }),
    );
  }

  Future<void> _setCategory(String id, String? categoryId) => _db.customUpdate(
    'UPDATE expenses SET categoryId = ? WHERE id = ?',
    variables: [Variable<String>(categoryId), Variable<String>(id)],
    updates: {_db.expenses},
  );
}
