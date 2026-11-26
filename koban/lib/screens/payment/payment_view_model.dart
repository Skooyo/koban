import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, immutable;

import '../../app/app_services.dart';
import '../../data/database.dart';
import '../../data/undoable.dart';
import '../../data/user_error.dart';
import '../../rules/types.dart';
import '../../ui/amount_input.dart';
import '../../ui/category_chips.dart';
import '../../ui/money.dart';

/// What the payment page shows. [amountText] is the raw typed text, as `AmountInput.formatter` keeps it.
@immutable
class PaymentForm {
  const PaymentForm({
    required this.amountText,
    required this.type,
    required this.categoryId,
    required this.postTime,
    required this.merchant,
    required this.notes,
    this.privateToGroups = false,
  });

  final String amountText;
  final TransactionType type;
  final String? categoryId;
  final int postTime;
  final String merchant;
  final String notes;

  /// True: the payment stays out of the shared totals that group members see.
  final bool privateToGroups;

  PaymentForm copyWith({
    String? amountText,
    TransactionType? type,
    Object? categoryId = _keep,
    int? postTime,
    String? merchant,
    String? notes,
    bool? privateToGroups,
  }) => PaymentForm(
    amountText: amountText ?? this.amountText,
    type: type ?? this.type,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as String?,
    postTime: postTime ?? this.postTime,
    merchant: merchant ?? this.merchant,
    notes: notes ?? this.notes,
    privateToGroups: privateToGroups ?? this.privateToGroups,
  );

  static const _keep = Object();

  @override
  bool operator ==(Object other) =>
      other is PaymentForm &&
      other.amountText == amountText &&
      other.type == type &&
      other.categoryId == categoryId &&
      other.postTime == postTime &&
      other.merchant == merchant &&
      other.notes == notes &&
      other.privateToGroups == privateToGroups;

  @override
  int get hashCode => Object.hash(
    amountText,
    type,
    categoryId,
    postTime,
    merchant,
    notes,
    privateToGroups,
  );
}

/// A shop from a recent payment, and the category its latest payment had.
@immutable
class RecentShop {
  const RecentShop(this.name, this.categoryId);

  final String name;
  final String? categoryId;
}

const _recentShopCount = 4;

/// The payment page shows six category chips, then More.
const paymentChipCount = 6;

/// The distinct shops of [newestFirst], by name without case, at most [_recentShopCount].
List<RecentShop> _recentShopsOf(List<Expense> newestFirst) {
  final shops = <String, RecentShop>{};
  for (final e in newestFirst) {
    final name = e.merchant?.trim() ?? '';
    final key = name.toLowerCase();
    if (name.isEmpty) continue;
    final seen = shops[key];
    if (seen == null) {
      if (shops.length == _recentShopCount) continue;
      shops[key] = RecentShop(name, e.categoryId);
    } else if (seen.categoryId == null && e.categoryId != null) {
      shops[key] = RecentShop(seen.name, e.categoryId);
    }
  }
  return shops.values.toList();
}

/// How the payment page ends.
sealed class PaymentResult {
  const PaymentResult();
}

/// The page closes. [message] shows as a snackbar under the page. Null shows nothing.
/// With [undo], the snackbar has an Undo button.
final class PaymentClosed extends PaymentResult {
  const PaymentClosed(this.message, {this.undo});

  final String? message;
  final Undoable? undo;
}

/// The payment is saved and the split editor opens for it.
final class PaymentOpenSplit extends PaymentResult {
  const PaymentOpenSplit(this.expenseId, {this.undo});

  final String expenseId;

  /// The Undo for past payments the save changed. The caller shows it after the split editor closes.
  final Undoable? undo;
}

/// The state and the rules of the payment page: add a payment, or edit one.
class PaymentViewModel extends ChangeNotifier with LoadErrors {
  PaymentViewModel(this._s, {String? expenseId}) : _expenseId = expenseId {
    _categorySub = _s.categories.watchAll().listen((list) {
      _categories = list;
      notifyListeners();
    }, onError: onLoadError);
    _mostUsedSub = _s.categories.watchMostUsedIds(paymentChipCount).listen((
      ids,
    ) {
      _mostUsed = ids;
      notifyListeners();
    }, onError: onLoadError);
    // ponytail: reads every saved payment to find 4 shops. Fine for a personal log.
    _recentSub = _s.expenses.watchAllActive().listen((list) {
      _recentShops = _recentShopsOf(list);
      notifyListeners();
    }, onError: onLoadError);
    if (expenseId == null) {
      _setLoaded(
        PaymentForm(
          amountText: '',
          type: TransactionType.withdraw,
          categoryId: null,
          postTime: _s.now().millisecondsSinceEpoch,
          merchant: '',
          notes: '',
        ),
      );
      ready = Future.value();
    } else {
      ready = _load(expenseId);
    }
  }

  final AppServices _s;
  final String? _expenseId;
  StreamSubscription<List<Category>>? _categorySub;
  StreamSubscription<List<String>>? _mostUsedSub;
  StreamSubscription<List<Expense>>? _recentSub;
  List<String> _mostUsed = const [];
  List<RecentShop> _recentShops = const [];

  /// Completes when the form shows. An edit of a missing payment sets [closeNow] first.
  late final Future<void> ready;

  PaymentForm? _form;
  PaymentForm? _initial;
  String? _loadedCategoryId;
  List<Category> _categories = const [];
  bool _saving = false;
  bool _disposed = false;
  bool _splitWithFriends = false;
  bool _changePast = true;
  int _pastCount = 0;
  String _pastKey = '';
  PaymentResult? _closeNow;

  bool get isEditing => _expenseId != null;

  /// The category the payment had when the page opened. Null when adding.
  String? get loadedCategoryId => _loadedCategoryId;

  /// Null while an edited payment loads.
  PaymentForm? get form => _form;

  /// True when the form is not what the page first showed.
  bool get hasChanges => _form != _initial;

  /// True after the first save or delete, so a double tap cannot act twice.
  bool get saving => _saving;

  List<Category> get categories => _categories;

  /// The category chips: the most used six, with the chosen category on the last chip if needed.
  List<Category> get chipCategories => chipCategoriesFor(
    _categories,
    _mostUsed,
    _form?.categoryId,
    count: paymentChipCount,
  );

  /// Up to four recent shops, newest first, for the chips above the categories.
  List<RecentShop> get recentShops => _recentShops;

  /// True when the owner is in a group.
  bool get inGroups => _s.inGroups.value;

  /// True: Save opens the split editor for the new payment. Only when adding a payment.
  bool get splitWithFriends => _splitWithFriends;

  /// How many past payments from this shop the picked category would change. Zero hides the checkbox.
  int get pastCount {
    final f = _form;
    final changes =
        f != null &&
        f.categoryId != null &&
        f.categoryId != _loadedCategoryId &&
        f.merchant.trim().isNotEmpty;
    return changes ? _pastCount : 0;
  }

  /// The checkbox "Also change N past payments". On by default.
  bool get changePast => _changePast;

  /// Set when the page must close at once: the edited payment does not exist.
  PaymentResult? get closeNow => _closeNow;

  void _setLoaded(PaymentForm f) {
    _initial = f;
    _form = f;
  }

  Future<void> _load(String id) async {
    final Expense? e;
    try {
      e = await _s.expenses.getById(id);
    } catch (error, stack) {
      if (!_disposed) onLoadError(error, stack);
      return;
    }
    if (_disposed) return;
    if (e == null) {
      _closeNow = const PaymentClosed(null);
    } else {
      _loadedCategoryId = e.categoryId;
      _setLoaded(
        PaymentForm(
          amountText: AmountInput.fromAmount(e.amount),
          type: e.transactionType,
          categoryId: e.categoryId,
          postTime: e.notificationPostTime,
          merchant: e.merchant ?? '',
          notes: e.notes ?? '',
          privateToGroups: e.privateToGroups,
        ),
      );
    }
    notifyListeners();
  }

  void _edit(PaymentForm Function(PaymentForm) change) {
    final f = _form;
    if (f == null) return;
    _form = change(f);
    notifyListeners();
    _countPast();
  }

  /// Counts the past payments the picked category would change, when the shop, category or direction changed.
  Future<void> _countPast() async {
    final f = _form;
    final category = f?.categoryId;
    if (f == null || category == null) return;
    final key = '${f.merchant.trim().toLowerCase()}|${f.type.dbName}|$category';
    if (key == _pastKey) return;
    _pastKey = key;
    _pastCount = 0;
    _changePast = true;
    final count = await _s.expenses.countPastForShop(
      f.merchant,
      f.type,
      category,
      excludeId: _expenseId,
    );
    if (_disposed || key != _pastKey) return;
    _pastCount = count;
    notifyListeners();
  }

  void setAmount(String text) => _edit((f) => f.copyWith(amountText: text));
  void setType(TransactionType t) => _edit((f) => f.copyWith(type: t));
  void setCategory(String? id) => _edit((f) => f.copyWith(categoryId: id));
  void setDate(int ms) => _edit((f) => f.copyWith(postTime: ms));

  /// A recent-shop chip: fills Shop, and the category that shop last had.
  void pickRecentShop(RecentShop shop) => _edit(
    (f) => f.copyWith(
      merchant: shop.name,
      categoryId: shop.categoryId ?? f.categoryId,
    ),
  );

  void setMerchant(String s) => _edit((f) => f.copyWith(merchant: s));
  void setNotes(String s) => _edit((f) => f.copyWith(notes: s));

  void setSplitWithFriends(bool on) {
    _splitWithFriends = on;
    notifyListeners();
  }

  void setChangePast(bool on) {
    _changePast = on;
    notifyListeners();
  }

  void setPrivateToGroups(bool on) =>
      _edit((f) => f.copyWith(privateToGroups: on));

  /// Saves the payment. Returns null when there is no valid amount or a save is under way.
  /// With [splitWithFriends] on, the split editor opens for the new payment.
  Future<PaymentResult?> save() => _persist(
    split: _splitWithFriends && _form?.type != TransactionType.receive,
  );

  /// Saves the edited payment, then asks for the split editor of it.
  /// Returns null when adding, when there is no valid amount, or when a save is under way.
  Future<PaymentResult?> saveAndSplit() async {
    if (_expenseId == null) return null;
    return _persist(split: true);
  }

  Future<PaymentResult?> _persist({required bool split}) async {
    final f = _form;
    final amount = f == null ? null : AmountInput.toAmount(f.amountText);
    if (f == null || amount == null || _saving) return null;
    _saving = true;
    notifyListeners();
    final merchant = f.merchant.trim().isEmpty ? null : f.merchant;
    final notes = f.notes.trim().isEmpty ? null : f.notes;
    final id = _expenseId;
    final Undoable? undo;
    if (id == null) {
      final added = await _s.expenses.addManualExpense(
        amount: amount,
        merchant: merchant,
        postTime: f.postTime,
        categoryId: f.categoryId,
        notes: notes,
        type: f.type,
        privateToGroups: f.privateToGroups,
        applyToPast: _changePast,
      );
      if (split) return PaymentOpenSplit(added.id, undo: added.undo);
      undo = added.undo;
    } else {
      undo = await _s.expenses.updateExpense(
        id,
        amount: amount,
        merchant: merchant,
        postTime: f.postTime,
        categoryId: f.categoryId,
        notes: notes,
        type: f.type,
        privateToGroups: f.privateToGroups,
        applyToPast: _changePast,
      );
      if (split) return PaymentOpenSplit(id, undo: undo);
    }
    return PaymentClosed(
      id != null && undo == null ? null : 'Payment saved',
      undo: undo,
    );
  }

  /// The payment no longer counts in totals. Returns null when a save or delete is under way.
  Future<PaymentResult?> delete() async {
    final id = _expenseId;
    if (id == null || _saving) return null;
    _saving = true;
    notifyListeners();
    final e = await _s.expenses.getById(id);
    final undo = await _s.expenses.dismissExpense(id);
    final shop = e?.merchant?.trim() ?? '';
    final what = [if (shop.isNotEmpty) shop, if (e != null) rm(e.amount)];
    return PaymentClosed(
      what.isEmpty ? 'Payment deleted' : 'Payment deleted: ${what.join(', ')}',
      undo: undo,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _categorySub?.cancel();
    _mostUsedSub?.cancel();
    _recentSub?.cancel();
    super.dispose();
  }
}
