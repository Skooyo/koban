import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import '../data/summaries.dart';
import '../theme/koban_theme.dart';
import '../theme/tokens.dart';

/// The filter value for payments with no category. Null means no filter.
const uncategorizedFilter = '__uncategorized';

bool matchesCategory(Expense e, String? filter) => switch (filter) {
  null => true,
  uncategorizedFilter => e.categoryId == null,
  _ => e.categoryId == filter,
};

/// One donut slice: a category, or several small ones folded together.
class DonutSlice {
  const DonutSlice({
    this.categoryId,
    required this.name,
    required this.total,
    this.folded = false,
  });

  final String? categoryId;
  final String name;
  final Decimal total;
  final bool folded;
}

const everythingElse = 'Everything else';
const _maxSlices = 6;

/// The slices in a fixed order. In this order no two neighbors have colors that look alike.
/// Other, custom and uncategorized spending folds into one gray slice at the end.
const _sliceOrder = [
  'food',
  'health',
  'transport',
  'entertainment',
  'shopping',
  'bills',
];

List<DonutSlice> donutSlices(List<CategoryBreakdown> breakdown) {
  final positive = breakdown.where((b) => b.total > Decimal.zero).toList();
  final named = [
    for (final id in _sliceOrder)
      ...positive.where((b) => b.categoryId == id).take(1),
  ];
  final rest = positive
      .where((b) => !_sliceOrder.contains(b.categoryId))
      .toList();
  while (named.length + (rest.isEmpty ? 0 : 1) > _maxSlices) {
    final smallest = named.reduce((a, b) => b.total < a.total ? b : a);
    named.remove(smallest);
    rest.add(smallest);
  }
  final slices = [
    for (final b in named)
      DonutSlice(categoryId: b.categoryId, name: b.name, total: b.total),
  ];
  return switch (rest.length) {
    0 => slices,
    1 => [
      ...slices,
      DonutSlice(
        categoryId: rest[0].categoryId,
        name: rest[0].name,
        total: rest[0].total,
      ),
    ],
    _ => [
      ...slices,
      DonutSlice(
        name: everythingElse,
        total: rest.fold(Decimal.zero, (a, b) => a + b.total),
        folded: true,
      ),
    ],
  };
}

Color sliceColor(
  BuildContext context,
  String? categoryId, {
  bool folded = false,
}) => folded || !_sliceOrder.contains(categoryId)
    ? MoneyColors.of(context).other
    : categoryColor(context, categoryId);

Color _sliceColor(BuildContext context, DonutSlice s) =>
    sliceColor(context, s.categoryId, folded: s.folded);

int _percentOf(Decimal part, Decimal whole) => whole == Decimal.zero
    ? 0
    : (part * Decimal.fromInt(100) / whole)
          .toDecimal(scaleOnInfinitePrecision: 10)
          .round()
          .toBigInt()
          .toInt();

/// Spending by category as one stacked bar. The bar is a button when [onTap] is set.
class CategoryBar extends StatelessWidget {
  const CategoryBar({super.key, required this.slices, this.onTap});

  final List<DonutSlice> slices;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    final whole = slices.fold(Decimal.zero, (a, b) => a + b.total);
    final summary = slices
        .map((s) => '${s.name} ${_percentOf(s.total, whole)} percent')
        .join(', ');
    return Semantics(
      label: 'Spending by category: $summary',
      button: onTap != null,
      onTap: onTap,
      onTapHint: onTap == null ? null : 'Filter by category',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(KobanRadius.full),
              child: SizedBox(
                height: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < slices.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        flex: math.max(
                          1,
                          (slices[i].total / whole).toDouble() * 1000 ~/ 1,
                        ),
                        child: ColoredBox(
                          color: _sliceColor(context, slices[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
