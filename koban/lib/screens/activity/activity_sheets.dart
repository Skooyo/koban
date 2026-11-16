import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../data/summaries.dart';
import '../../rules/periods.dart';
import '../../theme/koban_theme.dart';
import '../../ui/category_donut.dart';
import '../../ui/kit.dart';
import '../../ui/money.dart';
import '../../ui/sheets.dart';
import 'activity_view_model.dart';

Future<void> _showSheet(
  BuildContext context,
  String title,
  Widget Function(BuildContext) body,
) => showKobanSheet<void>(
  context: context,
  builder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: body(context),
        ),
      ),
    ],
  ),
);

/// One row of a pick sheet. It is a radio button for screen readers.
class _PickRow extends StatelessWidget {
  const _PickRow({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: child,
        ),
      ),
    ),
  );
}

/// The sheet to pick one category. Each row shows what was spent in it over the shown range.
Future<void> showCategoryFilterSheet(
  BuildContext context, {
  required List<Category> categories,
  required FilterTotals totals,
  required String? selected,
  required ValueChanged<String?> onPick,
}) {
  final spent = {
    for (final b in totals.breakdown)
      b.categoryId ?? uncategorizedFilter: b.total,
  };
  // No spending sorts last. Equal totals keep the category order (the index breaks the tie).
  final all = <(String, String)>[
    for (final c in categories) (c.id, c.name),
    (uncategorizedFilter, CategoryRepository.uncategorizedName),
  ];
  final order = [for (var i = 0; i < all.length; i++) i]
    ..sort((i, j) {
      final x = spent[all[i].$1];
      final y = spent[all[j].$1];
      if (x != null && y != null && x != y) return y.compareTo(x);
      if ((x == null) != (y == null)) return x == null ? 1 : -1;
      return i.compareTo(j);
    });
  final options = [for (final i in order) all[i]];
  return _showSheet(context, 'Show one category', (context) {
    void pick(String? id) {
      onPick(id);
      Navigator.pop(context);
    }

    return ListGroup(
      children: [
        _FilterOptionRow(
          dot: null,
          name: 'All categories',
          total: totals.total,
          selected: selected == null,
          onTap: () => pick(null),
        ),
        for (final (id, name) in options)
          _FilterOptionRow(
            dot: categoryColor(context, id == uncategorizedFilter ? null : id),
            name: name,
            total: spent[id],
            selected: selected == id,
            onTap: () => pick(id),
          ),
      ],
    );
  });
}

class _FilterOptionRow extends StatelessWidget {
  const _FilterOptionRow({
    required this.dot,
    required this.name,
    required this.total,
    required this.selected,
    required this.onTap,
  });

  final Color? dot;
  final String name;
  final Decimal? total;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return _PickRow(
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: dot == null
                    ? Icon(Icons.list, color: muted)
                    : CategoryDot(dot!),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                ),
              ),
            ),
            if (total != null)
              MoneyAmount(amount: total!, style: theme.textTheme.bodyLarge!)
            else
              Semantics(
                label: 'No spending',
                excludeSemantics: true,
                child: Text(
                  '—',
                  style: theme.textTheme.bodyLarge!.copyWith(color: muted),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 24,
                height: 24,
                child: selected
                    ? Icon(Icons.check, color: MoneyColors.of(context).goldText)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sheet to pick a month. Each row has a bar that compares its total with the largest.
Future<void> showMonthSheet(
  BuildContext context, {
  required List<MonthSummary> months,
  required YearMonth current,
  required ValueChanged<YearMonth> onPick,
}) {
  Decimal? largest;
  for (final m in months) {
    if (largest == null || m.total > largest) largest = m.total;
  }
  return _showSheet(context, 'Pick a month', (context) {
    final theme = Theme.of(context);
    return ListGroup(
      children: [
        for (final m in months)
          () {
            final yearMonth = YearMonth(m.year, m.month0 + 1);
            final isCurrent = yearMonth == current;
            return _PickRow(
              selected: isCurrent,
              onTap: () {
                onPick(yearMonth);
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            MonthNav.label(yearMonth),
                            style: theme.textTheme.titleMedium!.copyWith(
                              color: isCurrent
                                  ? MoneyColors.of(context).goldText
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        MoneyAmount(
                          amount: m.total,
                          style: theme.textTheme.bodyLarge!,
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: RelativeBar(
                        total: m.total,
                        max: largest,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }(),
      ],
    );
  });
}
