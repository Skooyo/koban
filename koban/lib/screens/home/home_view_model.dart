import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../data/legacy_import.dart';
import '../../data/summaries.dart';
import '../../data/user_error.dart';
import '../../rules/periods.dart';
import '../../rules/types.dart';
import '../../ui/alerts_off_row.dart';

/// The state of the Home tab: the access status, the 3 period summaries and the category names.
class HomeViewModel extends ChangeNotifier with LoadErrors {
  HomeViewModel(this._s) {
    _watchPeriods();
    _subs.add(
      _s.categories.watchAll().listen((list) {
        _categoryNames = {for (final c in list) c.id: c.name};
        notifyListeners();
      }, onError: onLoadError),
    );
    _subs.add(
      _s.paymentChecks.watchVisible().listen((v) {
        _waitingCount = v.length;
        _waitingSpent = [
          for (final p in v)
            if (p.transactionType == TransactionType.withdraw &&
                !p.directionUnclear)
              p.amount,
        ].fold(Decimal.zero, (a, b) => a + b);
        notifyListeners();
      }, onError: onLoadError),
    );
    // The settings notify after the payment apps picker saves.
    _s.settings.paymentAppsChosen.addListener(notifyListeners);
    _s.settings.paymentApps.addListener(notifyListeners);
    _subs.add(
      _s.expenses.watchHasAnyPayment().listen((v) {
        _hasAnyPayment = v;
        notifyListeners();
      }, onError: onLoadError),
    );
  }

  final AppServices _s;
  final List<StreamSubscription<Object?>> _subs = [];
  List<StreamSubscription<Object?>> _periodSubs = [];
  var _day = '';
  var _disposed = false;

  bool _isAccessGranted = false;
  PeriodSummary? _today;
  PeriodSummary? _week;
  PeriodSummary? _month;
  Map<String, String> _categoryNames = const {};
  bool _hasAnyPayment = true;
  int _waitingCount = 0;
  Decimal _waitingSpent = Decimal.zero;

  bool _alertsOff = false;

  bool get isAccessGranted => _isAccessGranted;

  /// True when Android blocks Koban's own notifications.
  bool get alertsOff => _alertsOff;
  PeriodSummary? get today => _today;
  PeriodSummary? get week => _week;
  PeriodSummary? get month => _month;
  Map<String, String> get categoryNames => _categoryNames;

  /// Waiting payments. Home shows a row when there is one or more.
  int get waitingCount => _waitingCount;

  /// The sum of the waiting payments that are Spent. Zero when none is known to be Spent.
  Decimal get waitingSpent => _waitingSpent;

  /// True when the owner chose the payment apps and chose none.
  bool get listensToNoApp =>
      _s.settings.paymentAppsChosen.value &&
      _s.settings.paymentApps.value.isEmpty;

  /// True while loading, so the first-payment card stays hidden until the database answers.
  bool get hasAnyPayment => _hasAnyPayment;

  /// True when the 0.1.1 import failed at this app start.
  bool get importFailed => _s.importResult is ImportFailed;

  String _dayStamp() {
    final n = _s.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Starts the 3 period streams for the day of the clock. A new day moves the ranges on.
  void _watchPeriods() {
    for (final sub in _periodSubs) {
      sub.cancel();
    }
    _day = _dayStamp();
    _periodSubs = [
      _s.expenses.watchPeriodSummary(SpendingPeriod.day).listen((v) {
        _today = v;
        notifyListeners();
      }, onError: onLoadError),
      _s.expenses.watchPeriodSummary(SpendingPeriod.week).listen((v) {
        _week = v;
        notifyListeners();
      }, onError: onLoadError),
      _s.expenses.watchPeriodSummary(SpendingPeriod.month).listen((v) {
        _month = v;
        notifyListeners();
      }, onError: onLoadError),
    ];
  }

  /// Reads the access status again and moves the day on. The screen calls it at the start and at each resume.
  Future<void> refresh() async {
    // The day moves first: a failed platform call must not freeze it.
    if (_dayStamp() != _day) _watchPeriods();
    final bool granted;
    final bool alertsOff;
    try {
      granted = await _s.listener.isAccessGranted();
      alertsOff = await alertsBlocked(_s.device);
    } catch (e) {
      // The screen calls refresh without a wait. A failed platform call keeps the last values.
      debugPrint('Koban: Home refresh failed (${e.runtimeType})');
      return;
    }
    if (_disposed) return;
    _isAccessGranted = granted;
    _alertsOff = alertsOff;
    notifyListeners();
  }

  /// Asks for the notification permission, then reads it again.
  Future<void> askForAlerts() async {
    await turnOnAlerts(_s.device);
    await refresh();
  }

  /// Points the Activity tab at the current month, with the current week when [withWeek].
  void selectActivity({required bool withWeek}) {
    final n = _s.now();
    final weekStart = withWeek
        ? PeriodCalculator.range(SpendingPeriod.week, anchor: n).$1
        : null;
    _s.activitySelection.show(YearMonth(n.year, n.month), weekStart: weekStart);
  }

  Future<void> openNotificationSettings() => _s.listener.openAccessSettings();

  @override
  void dispose() {
    _disposed = true;
    _s.settings.paymentAppsChosen.removeListener(notifyListeners);
    _s.settings.paymentApps.removeListener(notifyListeners);
    for (final sub in [..._subs, ..._periodSubs]) {
      sub.cancel();
    }
    super.dispose();
  }
}
