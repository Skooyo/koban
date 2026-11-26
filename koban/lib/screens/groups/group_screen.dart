import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../data/category_repository.dart';
import '../../online/group_repository.dart';
import '../../rules/periods.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../../ui/money.dart';
import '../../ui/scene_band.dart';
import 'group_dialogs.dart';
import 'groups_view_model.dart';

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// [n] with its English suffix: 1st, 2nd, 3rd, 4th, 11th.
String ordinal(int n) {
  final suffix = n % 100 >= 11 && n % 100 <= 13
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$suffix';
}

/// The color of a category name: the color of the built-in category with this
/// name (case ignored), else the color of "other". A person's own categories use "other".
Color _categoryColor(BuildContext context, String name) {
  final id = CategoryRepository.defaults
      .where((c) => c.name.toLowerCase() == name.toLowerCase())
      .map((c) => c.id)
      .firstOrNull;
  return categoryColor(context, id ?? 'other');
}

/// The page of one group. A port of the 0.1.1 `GroupsScreen.kt` `GroupScreen` and `GroupBody`.
class GroupScreen extends StatefulWidget {
  const GroupScreen(this.groupId, {this.madeName, super.key});

  final String groupId;

  /// Set when the person just made this group: the page shows the group code
  /// and Share code first, and a snackbar says "[madeName] made".
  final String? madeName;

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  GroupsViewModel? _vm;
  var _closing = false;

  /// True while a dialog or an action of a dialog runs. A second tap does nothing.
  var _asking = false;
  var _pulling = false;

  /// The user id of the member whose categories show.
  String? _open;
  var _help = false;

  /// The name of the category that ranks the members. Null is all spending.
  String? _category;

  @override
  void initState() {
    super.initState();
    final made = widget.madeName;
    if (made != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$made made')));
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm ??= GroupsViewModel(AppScope.of(context), groupId: widget.groupId)
      ..addListener(_onChange);
  }

  @override
  void dispose() {
    _vm
      ?..removeListener(_onChange)
      ..dispose();
    super.dispose();
  }

  /// Closes the page one time, and only when no dialog is over it.
  void _close() {
    if (_closing || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _closing = true;
    Navigator.of(context).pop();
  }

  void _onChange() {
    final vm = _vm!;
    if (!vm.groupExists) _close();
    if (vm.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showMessage());
    }
  }

  void _showMessage() {
    final vm = _vm!;
    final m = vm.message;
    if (!mounted || m == null) return;
    vm.messageShown();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Runs [show] when no other dialog of this page is open.
  Future<void> _ask(Future<void> Function() show) async {
    if (_asking) return;
    _asking = true;
    try {
      await show();
    } finally {
      _asking = false;
    }
  }

  Future<void> _pull() async {
    setState(() => _pulling = true);
    try {
      await _vm!.refresh();
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  Future<void> _rename(GroupSummary g) => _ask(
    () => askNameAndRun(
      context,
      _vm!,
      title: 'Rename group',
      label: 'Group name',
      start: g.name,
      confirm: 'Save',
      max: 40,
      action: (r, name) => r.rename(g.id, name),
    ),
  );

  Future<void> _newCode(GroupSummary g) => _ask(
    () => askConfirmAndRun(
      context,
      _vm!,
      title: 'Make a new code?',
      body: 'The old code stops working. Members stay in the group.',
      confirm: 'Make new code',
      action: (r) => r.newCode(g.id),
    ),
  );

  Future<void> _leave(GroupSummary g) => _ask(
    () => askConfirmAndRun(
      context,
      _vm!,
      title: 'Leave ${g.name}?',
      body: 'Members stop seeing your totals. To come back, ask the owner again with the group code.',
      confirm: 'Leave group',
      destructive: true,
      action: (r) => r.leave(g.id),
      onOk: _close,
    ),
  );

  Future<void> _remove(GroupSummary g, Member m) => _ask(
    () => askConfirmAndRun(
      context,
      _vm!,
      title: 'Remove ${m.alias}?',
      body:
          "${m.alias} stops seeing this group, and the members stop seeing ${m.alias}'s totals.",
      confirm: 'Remove',
      destructive: true,
      action: (r) => r.remove(g.id, m.userId),
    ),
  );

  Future<void> _handOver(GroupSummary g, Member m) => _ask(
    () => askConfirmAndRun(
      context,
      _vm!,
      title: 'Make ${m.alias} the owner?',
      body:
          '${m.alias} can then approve requests and remove members. You stay a member.',
      confirm: 'Make owner',
      action: (r) => r.handOver(g.id, m.userId),
    ),
  );

  Future<void> _share(GroupSummary g) async {
    final device = AppScope.of(context).device;
    try {
      await device.shareText(
        'Join my Koban group ${g.name}. In Koban, open Groups, tap Join with a group code, and type ${g.code}. No Koban yet? Ask me for an invite code.',
        chooserTitle: 'Share group code',
      );
    } catch (e) {
      // ONLINE LOGS rule R1: the type only.
      debugPrint('Koban: share failed (${e.runtimeType})');
    }
  }

  /// What [m] spent in [category]. A null [category] is the total.
  Decimal _amount(Member m, String? category) => category == null
      ? m.total
      : m.categories
            .where((c) => c.$1 == category)
            .fold(Decimal.zero, (sum, c) => sum + c.$2);

  /// The names of the categories of all members, the biggest sum first.
  List<String> _categoryNames(GroupDetail d) {
    final sums = <String, Decimal>{};
    for (final m in d.members) {
      for (final (c, v) in m.categories) {
        sums[c] = (sums[c] ?? Decimal.zero) + v;
      }
    }
    return (sums.keys.toList()..sort((a, b) => sums[b]!.compareTo(sums[a]!)));
  }

  /// Mon's line: a plain fact, never praise for spending less.
  ({MonFace face, String line, String? detail}) _monSay(
    GroupDetail? d,
    String? category,
    String? me,
    bool failed,
  ) {
    if (d == null) {
      return failed
          ? (
              face: MonFace.worry,
              line: 'Could not load the group.',
              detail: 'Check the internet connection, then try again.',
            )
          : (face: MonFace.idle, line: 'One moment.', detail: null);
    }
    if (d.members.every((m) => _amount(m, category) <= Decimal.zero)) {
      return (
        face: MonFace.idle,
        line: 'Nothing to rank yet.',
        detail: 'Totals show after members send them.',
      );
    }
    return (
      face: MonFace.idle,
      line: 'Members are listed by most spent.',
      detail: 'A higher total is not a win.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final d = vm.detail;
        final state = vm.state;
        final isOwner = d != null && d.group.ownerId == state.userId;
        final failed = d == null && vm.loadFailed && !state.loading;
        // A category that no member has any more does not stay selected.
        final category = d != null && _categoryNames(d).contains(_category)
            ? _category
            : null;
        final say = _monSay(d, category, state.userId, failed);
        final band = SceneBand(
          title: d?.group.name ?? 'Group',
          back: true,
          compact: true,
          face: say.face,
          line: say.line,
          detail: say.detail,
          stats: [
            if (d != null)
              '${d.members.length} ${d.members.length == 1 ? 'member' : 'members'}',
          ],
          action: d == null
              ? null
              : PopupMenuButton<VoidCallback>(
                  tooltip: 'Group actions',
                  icon: const Icon(Icons.more_vert),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainer.withValues(
                      alpha: 0.7,
                    ),
                    foregroundColor: scheme.onSurface,
                    minimumSize: const Size(48, 48),
                  ),
                  onSelected: (action) => action(),
                  itemBuilder: (_) => [
                    if (isOwner) ...[
                      PopupMenuItem(
                        value: () => _rename(d.group),
                        child: const Text('Rename group'),
                      ),
                      PopupMenuItem(
                        value: () => _newCode(d.group),
                        child: const Text('Make a new code'),
                      ),
                    ],
                    PopupMenuItem(
                      value: () => _leave(d.group),
                      child: const Text('Leave group'),
                    ),
                  ],
                ),
        );
        return Scaffold(
          body: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _pull,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    band,
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: d == null
                          ? (failed
                                ? Align(child: TonalButton('Try again', _pull))
                                : const SizedBox.shrink())
                          : _body(context, vm, d, isOwner, category),
                    ),
                  ],
                ),
              ),
              if (state.loading && !_pulling)
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 96),
                    child: RefreshProgressIndicator(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    GroupsViewModel vm,
    GroupDetail d,
    bool isOwner,
    String? category,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final s = AppScope.of(context);
    final now = s.now();
    final me = vm.state.userId;
    final period = vm.period;
    final mine = d.members.where((m) => m.userId == me).firstOrNull;
    final today = GroupPeriodMath.malaysiaDay(now);
    final loadedAt = vm.loadedAt;
    final names = _categoryNames(d);
    final ranked =
        [for (final (i, m) in d.members.indexed) (i, m, _amount(m, category))]
          ..sort(
            (a, b) => b.$3.compareTo(a.$3) != 0
                ? b.$3.compareTo(a.$3)
                : a.$1.compareTo(b.$1),
          );
    final top = ranked.fold(
      0.0,
      (t, r) => r.$3.toDouble() > t ? r.$3.toDouble() : t,
    );
    Widget card(Widget child, {Border? border}) => DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(KobanRadius.r24),
        border: border,
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
    final made = widget.madeName != null;
    final periodText = period == Period.week ? 'this week' : 'this month';
    final codeCard = card(
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group code',
                  style: theme.textTheme.bodySmall!.copyWith(color: muted),
                ),
                Text(d.group.code, style: theme.textTheme.headlineSmall),
              ],
            ),
          ),
          TonalButton('Share code', () => _share(d.group), icon: Icons.share),
        ],
      ),
    );
    final items = <Widget>[
      if (made) codeCard,
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            SegmentedControl(
              labels: const ['Week', 'Month'],
              selectedIndex: period == Period.week ? 0 : 1,
              onPick: (i) => vm.setPeriod(Period.values[i]),
            ),
            if (loadedAt != null)
              _RelativeText(
                time: loadedAt,
                now: now,
                // The 0.1.1 text says "just now" for the first minute.
                justNow: true,
                build: (rel) => Text(
                  'Updated $rel. Pull down to refresh.',
                  style: theme.textTheme.bodySmall!.copyWith(color: muted),
                ),
              ),
            if (names.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  spacing: 8,
                  children: [
                    _CategoryChip(
                      label: 'All',
                      color: null,
                      selected: category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    for (final c in names)
                      _CategoryChip(
                        label: c,
                        color: _categoryColor(context, c),
                        selected: category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Members',
                      style: theme.textTheme.titleSmall!.copyWith(color: muted),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _help = !_help),
                  tooltip: _help
                      ? 'Hide how to read this list'
                      : 'How to read this list',
                  icon: const Icon(Icons.info_outline),
                ),
              ],
            ),
            Text(
              '${category ?? 'All spending'} $periodText, most spent first',
              style: theme.textTheme.bodySmall!.copyWith(color: muted),
            ),
            for (final (rank, (_, m, amount)) in ranked.indexed)
              _MemberRow(
                key: ValueKey(m.userId),
                member: m,
                rank: rank + 1,
                amount: amount,
                category: category,
                isMe: m.userId == me,
                isOwner: isOwner,
                expanded: _open == m.userId,
                now: now,
                barFraction: top > 0
                    ? (amount.toDouble() / top).clamp(0.02, 1.0)
                    : 1,
                onToggle: () =>
                    setState(() => _open = _open == m.userId ? null : m.userId),
                onRemove: () => _remove(d.group, m),
                onHandOver: () => _handOver(d.group, m),
              ),
            if (_help)
              Text(
                'Members are listed by total spending. A higher total is not a win. Tap a member to see their categories, in their own names.',
                style: theme.textTheme.bodySmall!.copyWith(color: muted),
              ),
          ],
        ),
      ),
      if (mine != null)
        MergeSemantics(
          child: card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                Text(
                  period == Period.month
                      ? 'You spent in ${_months[today.month - 1]}'
                      : 'You spent this week',
                  style: theme.textTheme.bodyMedium!.copyWith(color: muted),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: MoneyText(
                    rm(mine.total),
                    style: theme.textTheme.displayMedium,
                    color: scheme.onSurface,
                  ),
                ),
                Builder(
                  builder: (_) {
                    final days = GroupPeriodMath.daysLeft(period, today: today);
                    return Text(
                      '${ordinal(d.members.indexOf(mine) + 1)} most spent of ${d.members.length} in ${d.group.name}. '
                      'Resets in $days ${days == 1 ? 'day' : 'days'}.',
                      style: theme.textTheme.bodyMedium,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      if (isOwner && d.requests.isNotEmpty)
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Text('Join requests', style: theme.textTheme.titleMedium),
              Text(
                'Only you see these, because you own the group. Requests end after 7 days.',
                style: theme.textTheme.bodySmall!.copyWith(color: muted),
              ),
              for (final r in d.requests)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      InitialsAvatar(r.alias, size: 36),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            r.alias,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => vm.run((x) => x.answer(r, false)),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        child: const Text('Decline'),
                      ),
                      TonalButton(
                        'Approve',
                        () => vm.run((x) => x.answer(r, true)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          border: Border.all(color: scheme.primary),
        ),
      if (!made) codeCard,
      card(
        Row(
          spacing: 12,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHigh,
              ),
              child: ExcludeSemantics(
                child: Icon(Icons.lock, size: 20, color: muted),
              ),
            ),
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Only category totals are shared',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      'Your shops, payments and notes stay on your phone.',
                      style: theme.textTheme.bodySmall!.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: items,
    );
  }
}

/// One category to rank by. A null [color] is "All".
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: ShapeDecoration(
                shape: StadiumBorder(
                  side: selected
                      ? BorderSide(color: accent, width: 2)
                      : BorderSide.none,
                ),
                color: selected
                    ? accent.withValues(alpha: 0.16)
                    : scheme.surfaceContainerHigh,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  if (color != null) CategoryDot(color!),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
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

/// A text that holds a relative time of the phone ("2 days ago"). It shows nothing
/// until the phone answers. With [justNow], the first minute reads "just now".
class _RelativeText extends StatefulWidget {
  const _RelativeText({
    required this.time,
    required this.now,
    required this.build,
    this.justNow = false,
  });

  final DateTime time;
  final DateTime now;
  final bool justNow;
  final Widget Function(String relative) build;

  @override
  State<_RelativeText> createState() => _RelativeTextState();
}

class _RelativeTextState extends State<_RelativeText> {
  String? _text;
  DateTime? _for;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_for != widget.time) _load();
  }

  @override
  void didUpdateWidget(_RelativeText old) {
    super.didUpdateWidget(old);
    if (_for != widget.time) _load();
  }

  void _load() {
    final time = _for = widget.time;
    if (widget.justNow &&
        widget.now.difference(time) < const Duration(seconds: 60)) {
      _text = 'just now';
      return;
    }
    _text = null;
    final device = AppScope.of(context).device;
    unawaited(
      device
          .relativeTime(
            time.millisecondsSinceEpoch,
            widget.now.millisecondsSinceEpoch,
          )
          .then((t) {
            if (mounted && _for == time) setState(() => _text = t);
          })
          .catchError((Object e, StackTrace s) {
            debugPrint('Koban: relative time failed (${e.runtimeType})');
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _text;
    return t == null ? const SizedBox.shrink() : widget.build(t);
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.member,
    required this.rank,
    required this.amount,
    required this.category,
    required this.isMe,
    required this.isOwner,
    required this.expanded,
    required this.now,
    required this.barFraction,
    required this.onToggle,
    required this.onRemove,
    required this.onHandOver,
  });

  final Member member;
  final int rank;

  /// What the member spent in [category], or in total when [category] is null.
  final Decimal amount;
  final String? category;
  final bool isMe;
  final bool isOwner;
  final bool expanded;
  final DateTime now;
  final double barFraction;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final VoidCallback onHandOver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final m = member;
    final updated = m.updatedAt;
    final stale =
        updated == null ||
        updated.isBefore(now.subtract(const Duration(hours: 24)));
    final name = isMe ? '${m.alias} (you)' : m.alias;
    final barColor = category == null
        ? null
        : _categoryColor(context, category!);
    return Semantics(
      button: true,
      onTapHint: expanded ? 'Hide categories' : 'Show categories',
      value: expanded ? 'Expanded' : 'Collapsed',
      child: Material(
        color: isMe ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Row(
                  children: [
                    ExcludeSemantics(
                      child: SizedBox(
                        width: 24,
                        child: Text(
                          '$rank',
                          style: tabular(
                            theme.textTheme.titleMedium!.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    InitialsAvatar(
                      m.alias,
                      size: 36,
                      tint: isMe ? scheme.primary : null,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          name,
                          style:
                              (isMe
                                      ? weighted(
                                          theme.textTheme.bodyLarge!,
                                          600,
                                        )
                                      : theme.textTheme.bodyLarge!)
                                  .copyWith(color: scheme.onSurface),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: MoneyText(
                        rm(amount),
                        style: theme.textTheme.titleMedium,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (m.categories.isNotEmpty)
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: barColor == null
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: barFraction,
                                child: SizedBox(
                                  height: 8,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Row(
                                      spacing: 2,
                                      children: [
                                        for (final (c, v) in m.categories)
                                          Expanded(
                                            flex:
                                                ((v.toDouble() < 0.01
                                                            ? 0.01
                                                            : v.toDouble()) *
                                                        100)
                                                    .round()
                                                    .clamp(1, 1 << 30),
                                            child: ColoredBox(
                                              color: _categoryColor(context, c),
                                              child: const SizedBox.expand(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: ColoredBox(
                                color: barColor.withValues(alpha: 0.16),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: barFraction,
                                    child: SizedBox(
                                      height: 8,
                                      child: ColoredBox(color: barColor),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                if (stale)
                  updated == null
                      ? Text(
                          'No totals sent yet',
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: muted,
                          ),
                        )
                      : _RelativeText(
                          time: updated,
                          now: now,
                          build: (rel) => Text(
                            'Updated $rel',
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                if (expanded) ...[
                  if (m.categories.isEmpty)
                    Text(
                      'No spending in this period.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  for (final (c, v) in m.categories)
                    Row(
                      children: [
                        CategoryDot(_categoryColor(context, c)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(c, style: theme.textTheme.bodyMedium),
                          ),
                        ),
                        MoneyText(rm(v), style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  if (isMe)
                    Text(
                      'This is what the other members see about you. Never shared: single payments, shops, times, notes and money in.',
                      style: theme.textTheme.bodySmall!.copyWith(color: muted),
                    ),
                  if (isOwner && !isMe)
                    Row(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: onHandOver,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text('Make owner'),
                        ),
                        TextButton(
                          onPressed: onRemove,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            foregroundColor: scheme.error,
                          ),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
