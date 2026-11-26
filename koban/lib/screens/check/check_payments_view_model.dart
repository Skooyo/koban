import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' hide Category;

import '../../app/app_services.dart';
import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../data/payment_checks.dart';
import '../../data/user_error.dart';
import '../../rules/amount_formatter.dart';
import '../../rules/top_up.dart';
import '../../rules/types.dart';
import '../../ui/category_chips.dart';

/// One card on the swipe screen. [categoryId] is the card's own category, or else the shop memory.
class CheckCard {
  const CheckCard({
    required this.payment,
    required this.appName,
    required this.categoryId,
    required this.categoryName,
  });

  final PendingPayment payment;
  final String appName;
  final String? categoryId;
  final String categoryName;
}

/// The state of Check payments. A port of `CheckPaymentsViewModel.kt`.
class CheckPaymentsViewModel extends ChangeNotifier with LoadErrors {
  CheckPaymentsViewModel(this._s) {
    _subs
      ..add(
        _s.categories.watchAll().listen((list) {
          _categories = list;
          _build();
        }, onError: onLoadError),
      )
      ..add(
        _s.categories.watchMostUsedIds(chipCount).listen((ids) {
          _mostUsed = ids;
          notifyListeners();
        }, onError: onLoadError),
      )
      ..add(
        _s.paymentChecks.watchVisible().listen((rows) {
          _rows = rows;
          _build();
        }, onError: onLoadError),
      );
  }

  static const alreadySavedMessage =
      'Already saved, so it was not added again.';

  /// The longest time the pill waits for the card after Undo.
  static const _undoReturn = Duration(milliseconds: 1000);

  final AppServices _s;
  final List<StreamSubscription<Object?>> _subs = [];
  final Map<String, String> _appNames = {};
  List<Category>? _categories;
  List<PendingPayment>? _rows;
  int _generation = 0;
  bool _disposed = false;

  List<CheckCard>? _cards;
  int _handled = 0;
  String? _undoLabel;
  Timer? _undoTimer;
  List<String> _heldIds = const [];

  /// The cards that Undo brought back. The pill goes when all are on the list again.
  Set<String> _returning = const {};

  /// Waiting payments, oldest first. Null until the first database read, so the screen does not close too early.
  List<CheckCard>? get cards => _cards;

  /// Cards swiped on this visit, for the "N of M" counter.
  int get handled => _handled;

  /// Text of the Undo pill, for example "Payment saved: Kedai Contoh · Undo". Null hides it.
  String? get undoLabel => _undoLabel;

  List<Category> get categories => _categories ?? const [];

  /// How many most used categories the sheet shows.
  static const chipCount = categoryChipCount;
  List<String> _mostUsed = const [];

  /// The most used category ids, for the top of the category sheet.
  List<String> get mostUsedIds => _mostUsed;

  /// The messages for a snackbar.
  Stream<String> get messages => _s.paymentChecks.results
      .where((r) => r == ConfirmResult.alreadySaved)
      .map((_) => alreadySavedMessage);

  Future<void> _build() async {
    final rows = _rows;
    final categories = _categories;
    if (rows == null || categories == null) return;
    final generation = ++_generation;
    final names = {for (final c in categories) c.id: c.name};
    final missing = {
      for (final p in rows)
        if (!_appNames.containsKey(p.sourcePackage)) p.sourcePackage,
    };
    if (missing.isNotEmpty) {
      var labels = const <String, String>{};
      try {
        labels = await _s.device.appLabels(missing);
      } catch (e, s) {
        developer.log(
          'App names not read',
          name: 'CheckPayments',
          error: e,
          stackTrace: s,
        );
      }
      // The package name when Android does not let Koban see the app.
      for (final p in missing) {
        _appNames[p] = labels[p] ?? p;
      }
    }
    final cards = <CheckCard>[];
    for (final p in rows) {
      final id =
          p.categoryId ?? await _s.merchants.categoryIdForMerchant(p.merchant);
      final known = names.containsKey(id) ? id : null;
      cards.add(
        CheckCard(
          payment: p,
          appName: _appNames[p.sourcePackage]!,
          categoryId: known,
          categoryName: names[known] ?? CategoryRepository.uncategorizedName,
        ),
      );
    }
    if (_disposed || generation != _generation) return;
    _cards = cards;
    if (_returning.isNotEmpty &&
        _returning.every((id) => cards.any((c) => c.payment.id == id))) {
      _clearPill();
    }
    notifyListeners();
  }

  void _clearPill() {
    _undoTimer?.cancel();
    _returning = const {};
    _undoLabel = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// True when Koban is sure of every field of the card: the direction, the shop,
  /// a known message format, a category, and not a wallet top-up.
  static bool isSure(CheckCard c) {
    final p = c.payment;
    return !p.directionUnclear &&
        p.format != CaptureFormat.unknown &&
        !looksLikeTopUp(p.rawNotificationText) &&
        (p.merchant ?? '').trim().isNotEmpty &&
        c.categoryId != null;
  }

  /// "Save all" shows when two or more cards wait and Koban is sure of each one.
  bool get canSaveAll {
    final cards = _cards;
    return cards != null && cards.length >= 2 && cards.every(isSure);
  }

  /// Holds the save ([save] true) or the drop of the card [id] for the Undo window.
  void swipe(String id, {required bool save}) {
    final payment = _cards
        ?.where((c) => c.payment.id == id)
        .firstOrNull
        ?.payment;
    if (payment == null) return;
    final what =
        payment.merchant ??
        '${AmountFormatter.currencySymbol(payment.currency)} '
            '${AmountFormatter.formatGrouped(payment.amount)}';
    _hold([id], '${save ? 'Payment saved' : 'Not a payment'}: $what', save);
  }

  /// Saves every waiting card as one hold, with one Undo.
  void saveAll() {
    final ids = [for (final c in _cards ?? const <CheckCard>[]) c.payment.id];
    if (ids.isEmpty) return;
    _hold(ids, '${ids.length} payments saved', true);
  }

  void _hold(List<String> ids, String what, bool save) {
    // Set the pill before the cards go, so the screen never sees an empty list with no pill.
    _clearPill();
    _undoLabel = '$what · Undo';
    _heldIds = ids;
    _s.paymentChecks.holdAll(ids, save: save);
    _handled += ids.length;
    _undoTimer = Timer(_s.paymentChecks.holdWindow, () {
      _undoLabel = null;
      _notify();
    });
    notifyListeners();
  }

  void undo() {
    _undoTimer?.cancel();
    final ids = _heldIds;
    _heldIds = const [];
    if (ids.isEmpty || !_s.paymentChecks.undo()) {
      _clearPill();
      notifyListeners();
      return;
    }
    _handled = (_handled - ids.length).clamp(0, _handled);
    // Keep the pill until the cards are back on the list, for the same reason as in swipe.
    _returning = ids.toSet();
    _undoTimer = Timer(_undoReturn, () {
      _clearPill();
      _notify();
    });
    notifyListeners();
  }

  /// Writes an edit of a card.
  Future<void> edit(PendingPayment p) async {
    try {
      await _s.paymentChecks.update(p);
    } catch (e, s) {
      developer.log(
        'Edit not saved',
        name: 'CheckPayments',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Commits the held swipe now. The screen calls it when the app goes to the background.
  void flushHold() {
    _heldIds = const [];
    _clearPill();
    _notify();
    _s.paymentChecks.flushHold();
  }

  @override
  void dispose() {
    _disposed = true;
    _undoTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _s.paymentChecks.flushHold();
    super.dispose();
  }
}
