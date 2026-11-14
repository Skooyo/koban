import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../data/legacy_import.dart';
import '../../data/summaries.dart';
import '../../rules/periods.dart';

/// The state of the Home tab: the access status, the 3 period summaries and the category names.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._s) {
    _watchPeriods();
    _subs.add(
      _s.categories.watchAll().listen((list) {
        _categoryNames = {for (final c in list) c.id: c.name};
        notifyListeners();
      }),
    );
    _subs.add(
      _s.expenses.watchHasAnyPayment().listen((v) {
        _hasAnyPayment = v;
        notifyListeners();
      }),
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

  bool get isAccessGranted => _isAccessGranted;
  PeriodSummary? get today => _today;
  PeriodSummary? get week => _week;
  PeriodSummary? get month => _month;
  Map<String, String> get categoryNames => _categoryNames;

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
      }),
      _s.expenses.watchPeriodSummary(SpendingPeriod.week).listen((v) {
        _week = v;
        notifyListeners();
      }),
      _s.expenses.watchPeriodSummary(SpendingPeriod.month).listen((v) {
        _month = v;
        notifyListeners();
      }),
    ];
  }

  /// Reads the access status again and moves the day on. The screen calls it at the start and at each resume.
  Future<void> refresh() async {
    // The day moves first: a failed platform call must not freeze it.
    if (_dayStamp() != _day) _watchPeriods();
    final granted = await _s.listener.isAccessGranted();
    if (_disposed) return;
    _isAccessGranted = granted;
    notifyListeners();
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
    for (final sub in [..._subs, ..._periodSubs]) {
      sub.cancel();
    }
    super.dispose();
  }
}
