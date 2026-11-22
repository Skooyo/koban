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
import '../../theme/mon.dart';
import '../../ui/category_donut.dart';
import '../../ui/kit.dart';
import '../../ui/money.dart';
import '../../ui/payment_row.dart';
import '../../ui/undo_snack_bar.dart';
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
  final _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm ??= ActivityViewModel(AppScope.of(context));
  }

  @override
  void dispose() {
    _search.dispose();
    _vm?.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    _vm!.setQuery('');
  }

  /// Shows the message that the payment page gives back.
  Future<void> _show(Future<PaymentResult?> page) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await page;
    if (result is PaymentClosed && result.message != null) {
      showUndoSnackBar(messenger, result.message!, undo: result.undo);
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
        final filterName = filter == null
            ? null
            : state.categoryNames[filter] ??
                  CategoryRepository.uncategorizedName;
        final query = state.query.trim();
        final summary = vm.summary;
        final scope = state.showAll
            ? 'all months'
            : selectedLabel ?? monthLabel;

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
                  _SearchField(controller: _search, onChanged: vm.setQuery),
                  const SizedBox(height: 12),
                  SegmentedControl(
                    labels: const ['Month', 'All'],
                    selectedIndex: state.showAll ? 1 : 0,
                    onPick: (i) => vm.setShowAll(i == 1),
                  ),
                  if (vm.loadError case final error?)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: WarningRow(error),
                    ),
                  if (summary != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _SummaryRow(
                        title: [
                          ?filterName,
                          if (query.isNotEmpty) '"$query"',
                        ].join(', '),
                        subtitle: '${_paymentsCount(summary.count)}, $scope',
                        total: summary.total,
                        leading: filter == null
                            ? const Icon(Icons.search)
                            : CategoryDot(
                                sliceColor(
                                  context,
                                  filter == uncategorizedFilter ? null : filter,
                                ),
                                size: 12,
                              ),
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
                    if (state.breakdown.any((b) => b.total > Decimal.zero))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _ByCategory(
                          breakdown: state.breakdown,
                          onPick: vm.setCategoryFilter,
                          onOther: _openFilter,
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
                filterName == null
                    ? 'No payments yet.'
                    : 'No $filterName payments.',
                filtered: filter != null,
                query: query,
                onClear: () => vm.setCategoryFilter(null),
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
              filterName == null
                  ? 'No payments in ${state.selectedWeek != null ? 'this week' : monthLabel}.'
                  : 'No $filterName payments in ${state.selectedWeek != null ? 'this week' : monthLabel}.',
              filtered: filter != null,
              query: query,
              onClear: () => vm.setCategoryFilter(null),
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
                  actions: [
                    _FilterButton(
                      onOpen: _openFilter,
                      active: filter == null ? 0 : 1,
                    ),
                  ],
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
                label: const Text('Add payment'),
                extendedTextStyle: weighted(theme.textTheme.titleMedium!, 700),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptySliver(
    BuildContext context,
    String title, {
    required bool filtered,
    required String query,
    required VoidCallback onClear,
  }) {
    final theme = Theme.of(context);
    final searching = query.isNotEmpty;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            const Mon(MonFace.idle, size: 64),
            const SizedBox(height: 12),
            Text(
              searching ? 'No payments match "$query".' : title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              searching
                  ? 'Try another word, or clear the search.'
                  : filtered
                  ? 'Clear the filter to see all payments.'
                  : 'Add one, or turn on tracking to find them.',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (searching || filtered) ...[
              const SizedBox(height: 16),
              TonalButton(
                searching ? 'Clear search' : 'Clear filter',
                searching ? _clearSearch : onClear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The outlined Filter button. It opens the category sheet.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onOpen, required this.active});

  final VoidCallback onOpen;

  /// How many filters are on. Above 0 the button shows the count and a gold-soft fill.
  final int active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = active > 0;
    final color = on ? scheme.onPrimaryContainer : scheme.onSurface;
    return Semantics(
      label: on ? 'Filter by category, $active on' : 'Filter by category',
      button: true,
      excludeSemantics: true,
      onTap: onOpen,
      child: Material(
        color: on ? scheme.primaryContainer : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: on ? scheme.primaryContainer : scheme.outlineVariant,
          ),
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
                  Icon(Icons.filter_list, size: 18, color: color),
                  const SizedBox(width: 6),
                  Text(
                    on ? 'Filter · $active' : 'Filter',
                    style: theme.textTheme.labelLarge!.copyWith(color: color),
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

/// The count and the spent total of what the list shows, while a category filter or a search is on.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.leading,
  });

  final String title;
  final String subtitle;
  final Decimal total;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListGroup(
      children: [
        KobanRow(
          title: title,
          subtitle: subtitle,
          leading: leading,
          trailing: MoneyAmount(
            amount: total,
            style: weighted(theme.textTheme.titleMedium!, 700),
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// The search field. It filters the list while the owner types.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      maxLines: 1,
      decoration: InputDecoration(
        hintText: 'Search shop or note',
        prefixIcon: Icon(Icons.search, color: muted),
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                ),
        ),
        border: const OutlineInputBorder(),
      ),
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

const _byCategoryRows = 4;

String _paymentsCount(int n) => n == 1 ? '1 payment' : '$n payments';

/// The top categories by amount, each a tap to filter. The rest fold into one row that opens the filter sheet.
class _ByCategory extends StatelessWidget {
  const _ByCategory({
    required this.breakdown,
    required this.onPick,
    required this.onOther,
  });

  final List<CategoryBreakdown> breakdown;
  final ValueChanged<String> onPick;
  final VoidCallback onOther;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = breakdown.where((b) => b.total > Decimal.zero).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final top = all.take(_byCategoryRows).toList();
    final rest = all.skip(_byCategoryRows).toList();
    Widget amount(Decimal v) => MoneyAmount(
      amount: v,
      style: theme.textTheme.titleMedium!,
      color: theme.colorScheme.onSurface,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('By category'),
        ListGroup(
          children: [
            for (final b in top)
              KobanRow(
                title: b.name,
                subtitle: _paymentsCount(b.count),
                leading: CategoryDot(
                  sliceColor(context, b.categoryId),
                  size: 12,
                ),
                trailing: amount(b.total),
                onTap: () => onPick(b.categoryId ?? uncategorizedFilter),
                onTapLabel: 'Show ${b.name} payments only',
              ),
            if (rest.isNotEmpty)
              KobanRow(
                title: 'Other categories',
                subtitle: _paymentsCount(
                  rest.fold(0, (sum, b) => sum + b.count),
                ),
                leading: CategoryDot(MoneyColors.of(context).other, size: 12),
                trailing: amount(
                  rest.fold(Decimal.zero, (sum, b) => sum + b.total),
                ),
                onTap: onOther,
                onTapLabel: 'Choose a category',
              ),
          ],
        ),
      ],
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
          color: theme.colorScheme.onSurface,
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
                  Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          color: theme.colorScheme.onSurface,
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
