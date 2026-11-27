import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/home_shell.dart';
import '../../app/routes.dart';
import '../../data/budget_repository.dart';
import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../data/legacy_import.dart';
import '../../data/summaries.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
import '../../theme/tokens.dart';
import '../../ui/alerts_off_row.dart';
import '../../ui/kit.dart';
import '../../ui/listener_status_banner.dart';
import '../../ui/money.dart';
import '../../ui/payment_row.dart';
import '../../ui/scene_band.dart';
import '../../ui/undo_snack_bar.dart';
import '../payment/payment_view_model.dart';
import 'home_view_model.dart';

/// The Home tab: Mon's band, payments to check, this week, the month, and the latest payments.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeViewModel? _vm;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => _vm?.refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm == null) {
      _vm = HomeViewModel(AppScope.of(context));
      _vm!.refresh();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _vm?.dispose();
    super.dispose();
  }

  void _openActivity({required bool withWeek}) {
    _vm!.selectActivity(withWeek: withWeek);
    HomeShell.of(context).select(KobanTab.activity);
  }

  /// Shows the message that the payment page gives back.
  Future<void> _show(Future<PaymentResult?> page) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await page;
    if (result is PaymentClosed && result.message != null) {
      showUndoSnackBar(messenger, result.message!, undo: result.undo);
    }
  }

  void _add() => _show(openPaymentNew(context));

  void _edit(String id) => _show(openPaymentEdit(context, id));

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final theme = Theme.of(context);
    const gap = SizedBox(height: 12);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final today = vm.today;
        final week = vm.week;
        final month = vm.month;
        final recent = week?.recentExpenses ?? const <Expense>[];
        final say = vm.monSay;
        return Stack(
          children: [
            ListView(
              padding: EdgeInsets.zero,
              children: [
                SceneBand(
                  title: vm.title,
                  compact: true,
                  onCoins: false,
                  face: say.face,
                  line: say.line,
                  detail: vm.isAccessGranted ? 'Tracking on' : 'Tracking off',
                  detailDot: vm.isAccessGranted
                      ? MoneyColors.of(context).received
                      : null,
                  action: SceneIconButton(
                    icon: Icons.settings,
                    tooltip: 'Settings',
                    onPressed: () => openSettings(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!vm.isAccessGranted) ...[
                        ListenerStatusBanner(
                          onEnable: vm.openNotificationSettings,
                        ),
                        gap,
                      ],
                      if (vm.waitingCount > 0) ...[
                        ListGroup(
                          children: [
                            KobanRow(
                              title: vm.waitingCount == 1
                                  ? '1 payment to check'
                                  : '${vm.waitingCount} payments to check',
                              subtitle: vm.waitingSpent > Decimal.zero
                                  ? '${rm(vm.waitingSpent)} found, not saved yet'
                                  : 'Found by Koban, not saved yet',
                              leading: Icon(
                                Icons.receipt,
                                color: MoneyColors.of(context).review,
                              ),
                              showChevron: true,
                              onTap: () => openCheckPayments(context),
                            ),
                          ],
                        ),
                        gap,
                      ],
                      // The 0.1.1 data did not move and is safe.
                      if (vm.importFailed) ...[
                        const WarningRow(importFailedMessage),
                        gap,
                      ],
                      if (vm.loadError case final error?) ...[
                        WarningRow(error),
                        gap,
                      ],
                      if (vm.alertsOff) ...[
                        AlertsOffRow(onTurnOn: vm.askForAlerts),
                        gap,
                      ],
                      if (vm.listensToNoApp) ...[
                        ListGroup(
                          children: [
                            KobanRow(
                              title: 'Koban listens to no app. Choose your payment apps.',
                              showChevron: true,
                              onTap: () => openPaymentApps(context),
                            ),
                          ],
                        ),
                        gap,
                      ],
                      if (vm.isAccessGranted &&
                          !vm.hasAnyPayment &&
                          vm.waitingCount == 0 &&
                          !vm.listensToNoApp) ...[
                        _FirstPaymentCard(
                          onAdd: _add,
                          onOpenSettings: () => openSettings(context),
                        ),
                        gap,
                      ],
                      if (week != null && today != null) ...[
                        _WeekCard(
                          week: week,
                          today: today,
                          days: vm.weekDays,
                          todayIndex: vm.todayIndex,
                          onOpen: () => _openActivity(withWeek: true),
                        ),
                        gap,
                      ],
                      if (month != null) ...[
                        ListGroup(
                          children: [
                            _PeriodRow(
                              month,
                              vm.budget,
                              () => _openActivity(withWeek: false),
                            ),
                          ],
                        ),
                        gap,
                      ],
                      if (recent.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: SectionHeading('Latest this week'),
                        ),
                        ListGroup(
                          children: [
                            for (final e in recent)
                              ExpenseListCard(
                                key: ValueKey(e.id),
                                expense: e,
                                categoryName:
                                    vm.categoryNames[e.categoryId] ??
                                    CategoryRepository.uncategorizedName,
                                timePattern: 'EEE HH:mm',
                                onEdit: () => _edit(e.id),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: _add,
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
}

/// This week: the total, one bar for each day with today in gold, and today's total.
/// A tap opens the Activity tab on this week.
class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.today,
    required this.days,
    required this.todayIndex,
    required this.onOpen,
  });

  final PeriodSummary week;
  final PeriodSummary today;
  final List<Decimal> days;
  final int todayIndex;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = scheme.onSurfaceVariant;
    final nothingToday =
        today.breakdown.isEmpty && today.received <= Decimal.zero;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(KobanRadius.r24),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        onTapHint: 'Open Activity',
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Spent this week',
                        style: text.bodyMedium!.copyWith(color: muted),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        week.subtitle,
                        textAlign: TextAlign.end,
                        style: text.bodySmall!.copyWith(color: muted),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: MoneyText(
                    rm(week.total),
                    style: text.displayLarge,
                    color: scheme.onSurface,
                  ),
                ),
                if (week.received > Decimal.zero)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: MoneyText(
                      '+ ${rm(week.received)} received',
                      style: text.bodyMedium,
                      color: MoneyColors.of(context).received,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _DayBars(days: days, todayIndex: todayIndex),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: nothingToday
                      ? Text(
                          'No payments yet today.',
                          style: text.bodyMedium!.copyWith(color: muted),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Spent today',
                                style: text.bodyMedium!.copyWith(color: muted),
                              ),
                            ),
                            MoneyText(
                              rm(today.total),
                              style: weighted(text.titleMedium!, 700),
                              color: scheme.onSurface,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _dayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Seven bars, Monday first, each as tall as that day's spending. Today is gold.
class _DayBars extends StatelessWidget {
  const _DayBars({required this.days, required this.todayIndex});

  final List<Decimal> days;
  final int todayIndex;

  static const _barMax = 60.0;
  static const _barMin = 6.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // The gold of the Add button: the primary color is a dark gold on the light theme.
    final gold =
        Theme.of(context).floatingActionButtonTheme.backgroundColor ??
        scheme.primary;
    final top = days.fold(Decimal.zero, (a, b) => b > a ? b : a);
    double height(Decimal d) => top == Decimal.zero
        ? _barMin
        : _barMin + (_barMax - _barMin) * (d / top).toDouble();
    final spoken = [
      for (var i = 0; i < 7; i++) '${_dayNames[i]} ${rm(days[i])}',
    ].join(', ');
    return Semantics(
      label: 'Spent each day: $spoken',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: height(days[i]),
                      decoration: BoxDecoration(
                        color: i == todayIndex ? gold : scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dayInitials[i],
                      style: text.labelSmall!.copyWith(
                        color: i == todayIndex
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// This month: the total on the right, the money received under it. With budget limits it
/// says "RM spent of RM limit" (both for the budgeted categories only) and, in red, how many categories are over.
class _PeriodRow extends StatelessWidget {
  const _PeriodRow(this.summary, this.budget, this.onTap);

  final PeriodSummary summary;
  final BudgetMonth? budget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final limits = budget;
    if (limits != null && !limits.isEmpty) {
      return KobanRow(
        title: summary.title,
        subtitle:
            'Budgets: ${rm(limits.totalSpent)} of ${rm(limits.totalLimit)}',
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyText(
              rm(summary.total),
              style: weighted(text.titleMedium!, 700),
              color: scheme.onSurface,
            ),
            if (limits.overCount > 0)
              Text(
                '${limits.overCount} over',
                style: weighted(
                  text.labelLarge!,
                  800,
                ).copyWith(color: scheme.error),
              ),
          ],
        ),
        showChevron: true,
        onTap: onTap,
      );
    }
    return KobanRow(
      title: summary.title,
      subtitle: summary.subtitle,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(
            rm(summary.total),
            style: weighted(text.titleMedium!, 700),
            color: scheme.onSurface,
          ),
          if (summary.received > Decimal.zero)
            MoneyText(
              '+ ${rm(summary.received)}',
              style: text.bodySmall,
              color: MoneyColors.of(context).received,
            ),
        ],
      ),
      showChevron: true,
      onTap: onTap,
    );
  }
}

/// The empty Home after setup: Mon waits.
class _FirstPaymentCard extends StatelessWidget {
  const _FirstPaymentCard({required this.onAdd, required this.onOpenSettings});

  final VoidCallback onAdd;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Mon(MonFace.idle, size: 56),
          const SizedBox(height: 12),
          Text(
            'Waiting for your first payment',
            style: text.titleMedium,
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: Text(
              'Pay for anything. It shows up here.',
              style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TonalButton('Add one by hand', onAdd),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        const Padding(
          padding: EdgeInsets.only(top: 24),
          child: SectionHeading('Set up later'),
        ),
        ListGroup(
          children: [
            KobanRow(
              title: 'Online features',
              subtitle: 'Read receipts, join groups',
              showChevron: true,
              onTap: onOpenSettings,
            ),
          ],
        ),
      ],
    );
  }
}
