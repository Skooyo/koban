import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' hide Category;

import '../../app/app_services.dart';
import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../data/payment_checks.dart';
import '../../rules/amount_formatter.dart';

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
class CheckPaymentsViewModel extends ChangeNotifier {
  CheckPaymentsViewModel(this._s) {
    _subs
      ..add(
        _s.categories.watchAll().listen((list) {
          _categories = list;
          _build();
        }),
      )
      ..add(
        _s.categories.watchMostUsedIds(chipCount).listen((ids) {
          _mostUsed = ids;
          notifyListeners();
        }),
      )
      ..add(
        _s.paymentChecks.watchVisible().listen((rows) {
          _rows = rows;
          _build();
        }),
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
  String? _heldId;

  /// The card that Undo brought back. The pill goes when it is on the list again.
  String? _returning;

  /// Waiting payments, oldest first. Null until the first database read, so the screen does not close too early.
  List<CheckCard>? get cards => _cards;

  /// Cards swiped on this visit, for the "N of M" counter.
  int get handled => _handled;

  /// Text of the Undo pill, for example "Saved Kedai Contoh · Undo". Null hides it.
  String? get undoLabel => _undoLabel;

  List<Category> get categories => _categories ?? const [];

  /// How many category chips a card shows.
  static const chipCount = 4;
  List<String> _mostUsed = const [];

  /// The chips of a card: the most used categories, then the rest by name.
  /// The card's own category [selectedId] takes the last chip when it is not in them.
  List<Category> chipCategories(String? selectedId) {
    final byId = {for (final c in categories) c.id: c};
    final chips = {
      for (final id in _mostUsed) ?byId[id],
      ...categories,
    }.take(chipCount).toList();
    final selected = byId[selectedId];
    if (selected != null && !chips.contains(selected)) {
      chips[chips.length - 1] = selected;
    }
    return chips;
  }

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
    if (_returning != null && cards.any((c) => c.payment.id == _returning)) {
      _clearPill();
    }
    notifyListeners();
  }

  void _clearPill() {
    _undoTimer?.cancel();
    _returning = null;
    _undoLabel = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
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
    // Set the pill before the card goes, so the screen never sees an empty list with no pill.
    _clearPill();
    _undoLabel = '${save ? 'Saved' : 'Skipped'} $what · Undo';
    _heldId = id;
    _s.paymentChecks.hold(id, save: save);
    _handled++;
    _undoTimer = Timer(_s.paymentChecks.holdWindow, () {
      _undoLabel = null;
      _notify();
    });
    notifyListeners();
  }

  void undo() {
    _undoTimer?.cancel();
    final id = _heldId;
    _heldId = null;
    if (id == null || !_s.paymentChecks.undo()) {
      _clearPill();
      notifyListeners();
      return;
    }
    if (_handled > 0) _handled--;
    // Keep the pill until the card is back on the list, for the same reason as in swipe.
    _returning = id;
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
    _heldId = null;
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
