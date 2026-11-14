import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../data/summaries.dart';
import '../../rules/periods.dart';
import '../../theme/koban_theme.dart';
import '../../ui/category_donut.dart';
import '../../ui/kit.dart';
import '../../ui/money.dart';
import '../../ui/payment_row.dart';
import '../payment/payment_view_model.dart';
import 'activity_sheets.dart';
import 'activity_view_model.dart';

final _dayFormat = DateFormat('d MMM', 'en_US');

String _weekLabel(WeekSummary w) =>
    '${_dayFormat.format(DateTime.fromMillisecondsSinceEpoch(w.startMs))}'
    ' – '
    '${_dayFormat.format(DateTime.fromMillisecondsSinceEpoch(w.endMs - 1))}';

/// The Activity tab: a month with its ring, weeks and payments, or all payments by month.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  ActivityViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm ??= ActivityViewModel(AppScope.of(context));
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  /// Shows the message that the payment page gives back.
  Future<void> _show(Future<PaymentResult?> page) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await page;
    if (result is PaymentClosed && result.message != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.message!)));
    }
  }

  void _openFilter() {
    final vm = _vm!;
    showCategoryFilterSheet(
      context,
      categories: vm.categories,
      totals: vm.filterTotals,
      selected: vm.state.categoryFilter,
      onPick: vm.setCategoryFilter,
    );
  }

  void _openMonths() {
    final vm = _vm!;
    showMonthSheet(
      context,
      months: vm.sheetMonths,
      current: vm.state.month,
      onPick: vm.pickMonth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        // The clock is read at each build, so the day labels follow midnight.
        final now = AppScope.of(context).now();
        final state = vm.state;
        final monthLabel = MonthNav.label(state.month);
        final selected = state.weeks
            .where((w) => w.startMs == state.selectedWeek)
            .firstOrNull;
        final selectedLabel = selected == null ? null : _weekLabel(selected);
        final filter = state.categoryFilter;

        List<Widget> days(List<Expense> expenses) => expensesByDay(
          expenses: expenses,
          categoryName: vm.categoryNameFor,
          onEdit: (e) => _show(openPaymentEdit(context, e.id)),
          now: now,
        );

        final slivers = <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedControl(
                    labels: const ['Month', 'All'],
                    selectedIndex: state.showAll ? 1 : 0,
                    onPick: (i) => vm.setShowAll(i == 1),
                  ),
                  if (filter != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _FilterChip(
                        name:
                            state.categoryNames[filter] ??
                            CategoryRepository.uncategorizedName,
                        total: state.showAll ? null : state.monthTotal,
                        period: selectedLabel ?? monthLabel,
                        onClear: () => vm.setCategoryFilter(null),
                      ),
                    ),
                  if (!state.showAll) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _MonthBar(
                        label: monthLabel,
                        canGoNext: state.canGoNext,
                        onPrevious: vm.previousMonth,
                        onNext: vm.nextMonth,
                        onPick: _openMonths,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _ChartCard(
                        slices: state.slices,
                        label: selectedLabel == null
                            ? 'Spent'
                            : 'Spent, $selectedLabel',
                        total: state.monthTotal,
                        received: state.monthReceived,
                        onRingTap: _openFilter,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _WeekStrip(
                        weeks: state.weeks,
                        selected: state.selectedWeek,
                        onToggle: vm.toggleWeek,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ];

        if (state.showAll) {
          final groups = vm.allMonths;
          if (groups != null && groups.isEmpty) {
            slivers.add(
              _emptySliver(
                context,
                filter != null
                    ? 'No payments in this category.'
                    : 'No payments yet.',
              ),
            );
          }
          for (final group in groups ?? const <ActivityMonthGroup>[]) {
            slivers.add(
              SliverMainAxisGroup(
                key: ValueKey('month-${group.month}'),
                slivers: [
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _MonthHeaderDelegate(
                      group: group,
                      extent: monthHeaderExtent(context, group),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.list(children: days(group.expenses)),
                  ),
                ],
              ),
            );
          }
        } else if (state.expenses.isEmpty) {
          slivers.add(
            _emptySliver(
              context,
              filter != null
                  ? 'No payments in this category.'
                  : state.selectedWeek != null
                  ? 'No payments in this week.'
                  : 'No payments in $monthLabel.',
            ),
          );
        } else {
          slivers.add(
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.list(children: days(state.expenses)),
            ),
          );
        }
        slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 112)));

        return Stack(
          children: [
            Column(
              children: [
                LargeTopBar(
                  title: 'Activity',
                  actions: [_FilterButton(onOpen: _openFilter)],
                ),
                Expanded(child: CustomScrollView(slivers: slivers)),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => _show(openPaymentNew(context)),
                icon: const Icon(Icons.add),
                label: Text(
                  'Add payment',
                  style: weighted(theme.textTheme.titleMedium!, 700),
                ),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptySliver(BuildContext context, String text) {
    final theme = Theme.of(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      sliver: SliverToBoxAdapter(
        child: Text(
          text,
          style: theme.textTheme.bodyLarge!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The outlined Filter button. It opens the category sheet.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Filter by category',
      button: true,
      excludeSemantics: true,
      onTap: onOpen,
      child: Material(
        color: Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter',
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The category now shown: a gold-soft chip that clears the filter, and what was spent in it.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.name,
    required this.total,
    required this.period,
    required this.onClear,
  });

  final String name;
  final Decimal? total;
  final String period;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Semantics(
            label: 'Filtered by $name. Clear filter',
            button: true,
            excludeSemantics: true,
            onTap: onClear,
            child: Material(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onClear,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          size: 18,
                          color: scheme.onPrimaryContainer,
                        ),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: weighted(
                                theme.textTheme.labelLarge!,
                                600,
                              ).copyWith(color: scheme.onPrimaryContainer),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (total != null) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              children: [
                MoneyAmount(
                  amount: total!,
                  style: theme.textTheme.bodyMedium!,
                  color: muted,
                ),
                Flexible(
                  child: Text(
                    ' $period',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium!.copyWith(color: muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The ring, "Spent" with the big total, and the money received, in one card.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.slices,
    required this.label,
    required this.total,
    required this.received,
    required this.onRingTap,
  });

  final List<DonutSlice> slices;
  final String label;
  final Decimal total;
  final Decimal received;
  final VoidCallback onRingTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CategoryDonut(slices: slices, onTap: onRingTap),
          if (slices.isNotEmpty) const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: MoneyText(
                    rm(total),
                    style: theme.textTheme.displayMedium,
                    color: scheme.onSurface,
                  ),
                ),
                if (received > Decimal.zero)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: MoneyText(
                      '+ ${rm(received)} received',
                      style: theme.textTheme.bodyMedium,
                      color: MoneyColors.of(context).received,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Previous month, the month name that opens the month sheet, and next month.
class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.label,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final String label;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          tooltip: 'Previous month',
          icon: const Icon(Icons.keyboard_arrow_left),
        ),
        Expanded(
          child: Semantics(
            onTapHint: 'Pick a month',
            child: TextButton(
              onPressed: onPick,
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          tooltip: 'Next month',
          icon: const Icon(Icons.keyboard_arrow_right),
        ),
      ],
    );
  }
}

/// Whole month and one chip for each week. A tap on the chosen chip clears it.
class _WeekStrip extends StatefulWidget {
  const _WeekStrip({
    required this.weeks,
    required this.selected,
    required this.onToggle,
  });

  final List<WeekSummary> weeks;
  final int? selected;
  final ValueChanged<int> onToggle;

  @override
  State<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends State<_WeekStrip> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scrollToSelected();
  }

  @override
  void didUpdateWidget(_WeekStrip old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected || old.weeks != widget.weeks) {
      _scrollToSelected();
    }
  }

  /// Brings the chosen week to the start of the strip.
  void _scrollToSelected() {
    if (widget.selected == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _PeriodChip(
            selected: widget.selected == null,
            onTap: () {
              final s = widget.selected;
              if (s != null) widget.onToggle(s);
            },
            child: Text(
              'Whole month',
              style: weighted(theme.textTheme.labelLarge!, 600),
            ),
          ),
          for (final week in widget.weeks) ...[
            const SizedBox(width: 8),
            Builder(
              key: week.startMs == widget.selected ? _selectedKey : null,
              builder: (context) {
                final on = week.startMs == widget.selected;
                final color = on
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant;
                return _PeriodChip(
                  selected: on,
                  onTap: () => widget.onToggle(week.startMs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weekLabel(week),
                        style: theme.textTheme.labelMedium!.copyWith(
                          color: color,
                        ),
                      ),
                      MoneyAmount(
                        amount: week.total,
                        style: theme.textTheme.titleSmall!,
                        color: on
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// A chip of the week strip: gold-soft with a check when chosen, outlined when not.
class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: selected
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.check,
                          size: 18,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                      child: child,
                    ),
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

/// The height of the header of a month at the text scale in use.
@visibleForTesting
double monthHeaderExtent(BuildContext context, ActivityMonthGroup group) {
  final text = Theme.of(context).textTheme;
  final scaler = MediaQuery.textScalerOf(context);
  // 20 above and 4 below, the title line, and the received line when there is money received.
  return 24 +
      scaler.scale(text.titleMedium!.fontSize! * 1.5) +
      (group.received > Decimal.zero
          ? scaler.scale(text.bodyMedium!.fontSize! * 1.5)
          : 0);
}

/// The month header of the All view. It stays at the top while the payments of its month pass.
class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MonthHeaderDelegate({required this.group, required this.extent});

  final ActivityMonthGroup group;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  bool shouldRebuild(_MonthHeaderDelegate old) =>
      old.group != group || old.extent != extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: MergeSemantics(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          MonthNav.label(group.month),
                          style: weighted(theme.textTheme.titleMedium!, 700),
                        ),
                      ),
                      MoneyAmount(
                        amount: group.total,
                        style: theme.textTheme.titleMedium!,
                      ),
                    ],
                  ),
                  ReceivedNote(group.received),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
