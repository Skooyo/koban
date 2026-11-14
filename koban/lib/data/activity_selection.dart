import 'package:flutter/foundation.dart';

import '../rules/periods.dart';

/// What the Activity tab shows: a month, or all payments.
@immutable
class Selection {
  const Selection({
    required this.month,
    this.weekStart,
    this.categoryFilter,
    this.showAll = false,
  });

  final YearMonth month;
  final int? weekStart;
  final String? categoryFilter;
  final bool showAll;

  @override
  bool operator ==(Object other) =>
      other is Selection &&
      other.month == month &&
      other.weekStart == weekStart &&
      other.categoryFilter == categoryFilter &&
      other.showAll == showAll;

  @override
  int get hashCode => Object.hash(month, weekStart, categoryFilter, showAll);
}

/// The month (with an optional week and category filter) or the All view of the Activity tab.
/// Home sets it. The Activity tab keeps it. A port of `ActivitySelection.kt`.
class ActivitySelection extends ValueNotifier<Selection> {
  ActivitySelection(YearMonth now) : super(Selection(month: now));

  /// Shows [month] and [weekStart] in the Month view. It clears the category filter unless one is given.
  void show(YearMonth month, {int? weekStart, String? categoryFilter}) {
    value = Selection(
      month: month,
      weekStart: weekStart,
      categoryFilter: categoryFilter,
    );
  }

  void setCategoryFilter(String? filter) {
    final v = value;
    value = Selection(
      month: v.month,
      weekStart: v.weekStart,
      categoryFilter: filter,
      showAll: v.showAll,
    );
  }

  void setShowAll(bool showAll) {
    final v = value;
    value = Selection(
      month: v.month,
      weekStart: v.weekStart,
      categoryFilter: v.categoryFilter,
      showAll: showAll,
    );
  }
}
