import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, immutable;

import '../../app/app_services.dart';
import '../../data/database.dart';
import '../../rules/types.dart';
import '../../ui/amount_input.dart';

/// What the payment page shows. [amountText] is the raw number-pad text, as `AmountInput` keeps it.
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

/// How the payment page ends.
sealed class PaymentResult {
  const PaymentResult();
}

/// The page closes. [message] shows as a snackbar under the page. Null shows nothing.
final class PaymentClosed extends PaymentResult {
  const PaymentClosed(this.message);

  final String? message;
}

/// The payment is saved and the split editor opens for it.
final class PaymentOpenSplit extends PaymentResult {
  const PaymentOpenSplit(this.expenseId);

  final String expenseId;
}

/// The state and the rules of the payment page: add a payment, or edit one.
class PaymentViewModel extends ChangeNotifier {
  PaymentViewModel(this._s, {String? expenseId}) : _expenseId = expenseId {
    _categorySub = _s.categories.watchAll().listen((list) {
      _categories = list;
      notifyListeners();
    });
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

  /// Completes when the form shows. An edit of a missing payment sets [closeNow] first.
  late final Future<void> ready;

  PaymentForm? _form;
  PaymentForm? _initial;
  String? _loadedCategoryId;
  List<Category> _categories = const [];
  bool _saving = false;
  bool _disposed = false;
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

  /// True when the owner is in a group.
  bool get inGroups => _s.inGroups.value;

  /// Set when the page must close at once: the edited payment does not exist.
  PaymentResult? get closeNow => _closeNow;

  void _setLoaded(PaymentForm f) {
    _initial = f;
    _form = f;
  }

  Future<void> _load(String id) async {
    final e = await _s.expenses.getById(id);
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
  }

  void press(String key) => _edit(
    (f) => f.copyWith(amountText: AmountInput.press(f.amountText, key)),
  );
  void backspace() =>
      _edit((f) => f.copyWith(amountText: AmountInput.backspace(f.amountText)));
  void setType(TransactionType t) => _edit((f) => f.copyWith(type: t));
  void setCategory(String? id) => _edit((f) => f.copyWith(categoryId: id));
  void setDate(int ms) => _edit((f) => f.copyWith(postTime: ms));
  void setMerchant(String s) => _edit((f) => f.copyWith(merchant: s));
  void setNotes(String s) => _edit((f) => f.copyWith(notes: s));
  void setPrivateToGroups(bool on) =>
      _edit((f) => f.copyWith(privateToGroups: on));

  /// Saves the payment. Returns null when there is no valid amount or a save is under way.
  Future<PaymentResult?> save() async {
    final f = _form;
    final amount = f == null ? null : AmountInput.toAmount(f.amountText);
    if (f == null || amount == null || _saving) return null;
    _saving = true;
    notifyListeners();
    final merchant = f.merchant.trim().isEmpty ? null : f.merchant;
    final notes = f.notes.trim().isEmpty ? null : f.notes;
    final id = _expenseId;
    if (id == null) {
      await _s.expenses.addManualExpense(
        amount: amount,
        merchant: merchant,
        postTime: f.postTime,
        categoryId: f.categoryId,
        notes: notes,
        type: f.type,
        privateToGroups: f.privateToGroups,
      );
    } else {
      await _s.expenses.updateExpense(
        id,
        amount: amount,
        merchant: merchant,
        postTime: f.postTime,
        categoryId: f.categoryId,
        notes: notes,
        type: f.type,
        privateToGroups: f.privateToGroups,
      );
    }
    return PaymentClosed(
      id != null
          ? null
          : f.type == TransactionType.receive
          ? 'Income added'
          : 'Expense added',
    );
  }

  /// The payment no longer counts in totals. Returns null when a save or delete is under way.
  Future<PaymentResult?> delete() async {
    final id = _expenseId;
    if (id == null || _saving) return null;
    _saving = true;
    notifyListeners();
    await _s.expenses.dismissExpense(id);
    return const PaymentClosed('Payment deleted');
  }

  @override
  void dispose() {
    _disposed = true;
    _categorySub?.cancel();
    super.dispose();
  }
}
