import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../data/budget_repository.dart';
import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../data/summaries.dart';
import '../../rules/periods.dart';
import '../../theme/koban_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/category_donut.dart';
import '../../ui/kit.dart';
import '../../ui/money.dart';
import '../../ui/payment_row.dart';
import '../../ui/scene_band.dart';
import '../../ui/undo_snack_bar.dart';
import '../payment/payment_view_model.dart';
import 'activity_mon.dart';
import 'activity_sheets.dart';
import 'activity_view_model.dart';

/// The Activity tab: a month with its category bar, weeks and payments, or all payments by month.
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
        final selectedLabel = selected?.label;
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

        final say = activityMon(
          showAll: state.showAll,
          searching: query.isNotEmpty,
          filtered: filter != null,
          monthLabel: monthLabel,
          breakdown: state.breakdown,
          overBudget: vm.overBudget,
        );

        final slivers = <Widget>[
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SceneBand(
                  title: 'Activity',
                  compact: true,
                  face: say.face,
                  line: say.line,
                  detail: say.detail,
                  action: IntrinsicWidth(
                    child: SegmentedControl(
                      labels: const ['Month', 'All'],
                      selectedIndex: state.showAll ? 1 : 0,
                      onPick: (i) => vm.setShowAll(i == 1),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MonthCard(
                        monthBar: state.showAll
                            ? null
                            : _MonthBar(
                                label: monthLabel,
                                canGoNext: state.canGoNext,
                                onPrevious: vm.previousMonth,
                                onNext: vm.nextMonth,
                                onPick: _openMonths,
                              ),
                        chart: state.showAll
                            ? null
                            : _ChartBody(
                                slices: state.slices,
                                label: selectedLabel == null
                                    ? 'Spent'
                                    : 'Spent, $selectedLabel',
                                total: state.monthTotal,
                                received: state.monthReceived,
                                onBarTap: _openFilter,
                              ),
                        categories:
                            state.showAll ||
                                !state.breakdown.any(
                                  (b) => b.total > Decimal.zero,
                                )
                            ? null
                            : _ByCategory(
                                breakdown: state.breakdown,
                                budgets: vm.budgets,
                                onPick: vm.setCategoryFilter,
                              ),
                        filter: filter == null
                            ? _FilterButton(onOpen: _openFilter)
                            : _FilterChip(
                                name: filterName!,
                                color: sliceColor(
                                  context,
                                  filter == uncategorizedFilter ? null : filter,
                                ),
                                onOpen: _openFilter,
                                onClear: () => vm.setCategoryFilter(null),
                              ),
                      ),
                      if (!state.showAll)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _WeekStrip(
                            weeks: state.weeks,
                            selected: state.selectedWeek,
                            onToggle: vm.toggleWeek,
                          ),
                        ),
                      const SizedBox(height: 12),
                      _SearchField(controller: _search, onChanged: vm.setQuery),
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
                            subtitle:
                                '${_paymentsCount(summary.count)}, $scope',
                            total: summary.total,
                            leading: filter == null
                                ? const Icon(Icons.search)
                                : CategoryDot(
                                    sliceColor(
                                      context,
                                      filter == uncategorizedFilter
                                          ? null
                                          : filter,
                                    ),
                                    size: 12,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
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
        } else if (vm.loading) {
          slivers.add(const SliverToBoxAdapter(child: LoadingLine()));
        } else if (vm.loadError != null) {
          // The error row above says it. No empty copy for data that did not load.
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
            CustomScrollView(slivers: slivers),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => _show(openPaymentNew(context)),
                icon: const Icon(Icons.add),
                label: const Text('Add payment'),
                extendedTextStyle: weighted(theme.textTheme.titleMedium!, 700),
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

/// The Filter button. It opens the category sheet.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: 'Filter by category',
      button: true,
      excludeSemantics: true,
      onTap: onOpen,
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: const StadiumBorder(),
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
                  Icon(Icons.filter_list, size: 18, color: scheme.onSurface),
                  const SizedBox(width: 6),
                  Text(
                    'Filter',
                    style: theme.textTheme.labelLarge!.copyWith(
                      color: scheme.onSurface,
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

/// The chosen category as a chip. A tap on the name opens the sheet. The cross clears the filter.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.name,
    required this.color,
    required this.onOpen,
    required this.onClear,
  });

  final String name;
  final Color color;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primaryContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Semantics(
              onTapHint: 'Change the category filter',
              child: InkWell(
                onTap: onOpen,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CategoryDot(color, size: 12),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge!.copyWith(
                              color: scheme.onPrimaryContainer,
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
          IconButton(
            onPressed: onClear,
            tooltip: 'Clear filter',
            color: scheme.onPrimaryContainer,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      maxLines: 1,
      decoration: InputDecoration(
        filled: true,
        fillColor: scheme.surfaceContainer,
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
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(KobanRadius.full)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// The card under the band: for one month the month bar, the total, the category bar and the category list. The filter is at the end.
class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.monthBar,
    required this.chart,
    required this.categories,
    required this.filter,
  });

  final Widget? monthBar;
  final Widget? chart;
  final Widget? categories;
  final Widget filter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(KobanRadius.r24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?monthBar,
          ?chart,
          ?categories,
          Align(alignment: Alignment.centerLeft, child: filter),
        ],
      ),
    );
  }
}

/// "Spent" with the big total, the money received, and the category bar.
class _ChartBody extends StatelessWidget {
  const _ChartBody({
    required this.slices,
    required this.label,
    required this.total,
    required this.received,
    required this.onBarTap,
  });

  final List<DonutSlice> slices;
  final String label;
  final Decimal total;
  final Decimal received;
  final VoidCallback onBarTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
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
        if (slices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CategoryBar(slices: slices, onTap: onBarTap),
          ),
      ],
    );
  }
}

const _byCategoryRows = 4;

String _paymentsCount(int n) => n == 1 ? '1 payment' : '$n payments';

/// The top categories by amount with their share and budget bar, each a tap to filter.
/// The rest fold into one row that opens in place.
class _ByCategory extends StatefulWidget {
  const _ByCategory({
    required this.breakdown,
    required this.budgets,
    required this.onPick,
  });

  final List<CategoryBreakdown> breakdown;
  final Map<String, CategoryBudget> budgets;
  final ValueChanged<String> onPick;

  @override
  State<_ByCategory> createState() => _ByCategoryState();
}

class _ByCategoryState extends State<_ByCategory> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = widget.breakdown.where((b) => b.total > Decimal.zero).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final rest = all.skip(_byCategoryRows).toList();
    final shown = _open ? all : all.take(_byCategoryRows).toList();
    final restTotal = rest.fold(Decimal.zero, (sum, b) => sum + b.total);
    final restName = rest.length == 1
        ? '1 more category'
        : '${rest.length} more categories';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in shown) ...[
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          _CategoryRow(
            item: b,
            budget: widget.budgets[b.categoryId],
            onTap: () => widget.onPick(b.categoryId ?? uncategorizedFilter),
          ),
        ],
        if (rest.isNotEmpty) ...[
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _open ? 'Show fewer' : restName,
                        style: theme.textTheme.labelLarge!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (!_open) ...[
                      MoneyAmount(
                        amount: restTotal,
                        style: theme.textTheme.bodyMedium!,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A category: dot, name, share and amount. With a [budget]: a bar and "RM 452.80 of RM 500.00".
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.budget,
    required this.onTap,
  });

  final CategoryBreakdown item;
  final CategoryBudget? budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final dotColor = sliceColor(context, item.categoryId);
    final percent = '${(item.fraction * 100).round()}%';
    final b = budget;
    Widget? budgetLines;
    if (b != null) {
      final colors = MoneyColors.of(context);
      final (barColor, note, noteColor) = switch (b.state) {
        BudgetState.under => (
          dotColor,
          '${rm(b.limit - b.spent)} left',
          scheme.onSurfaceVariant,
        ),
        BudgetState.warn => (
          colors.warn,
          '${rm(b.limit - b.spent)} left',
          colors.warn,
        ),
        BudgetState.over => (scheme.error, '${rm(b.over)} over', scheme.error),
      };
      budgetLines = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ExcludeSemantics(
              child: RelativeBar(
                total: b.spent,
                max: b.limit,
                color: barColor,
                height: 6,
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            children: [
              Text('${rm(b.spent)} of ${rm(b.limit)}', style: muted),
              Text(
                note,
                style: weighted(
                  theme.textTheme.bodyMedium!,
                  b.state == BudgetState.under ? 500 : 800,
                ).copyWith(color: noteColor),
              ),
            ],
          ),
        ],
      );
    }
    return Semantics(
      onTapHint: 'Show ${item.name} payments only',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CategoryDot(dotColor, size: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.name,
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(percent, style: tabular(muted)),
                    const SizedBox(width: 12),
                    MoneyAmount(
                      amount: item.total,
                      style: theme.textTheme.titleMedium!,
                    ),
                  ],
                ),
                ?budgetLines,
              ],
            ),
          ),
        ),
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
                        week.label,
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
