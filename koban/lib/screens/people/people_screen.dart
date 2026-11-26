import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../data/people_repository.dart';
import '../../data/user_error.dart';
import '../../rules/people_math.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../../ui/money.dart';
import '../../ui/scene_band.dart';
import '../../ui/sheets.dart';
import '../person/person_dialogs.dart' show personDate;
import 'people_view_model.dart';

String _groupTitle(PeopleGroup group) => switch (group) {
  PeopleGroup.youOwe => 'You owe',
  PeopleGroup.owesYou => 'They owe you',
  PeopleGroup.others => 'Everyone else',
};

/// The Java `String.hashCode` of [s], as a signed 32-bit number.
/// It keeps the avatar color of each person the same as in 0.1.1.
int jvmHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (31 * h + c) & 0xFFFFFFFF;
  }
  return h >= 0x80000000 ? h - 0x100000000 : h;
}

/// The People tab: search, the people in groups, the past splits and Add person.
/// A port of `PeopleScreen.kt`.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  PeopleViewModel? _vm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm ??= PeopleViewModel(AppScope.of(context));
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final added = await showKobanSheet<({String id, String? qrError})>(
      context: context,
      builder: (_) => _AddPersonSheet(vm: _vm!),
    );
    if (added == null || !mounted) return;
    if (added.qrError case final error?) {
      messenger.showSnackBar(
        SnackBar(content: Text('$error Add the QR on the person page.')),
      );
    }
    await openPerson(context, added.id);
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final money = MoneyColors.of(context);
    final avatarColors = [
      money.red,
      money.blue,
      money.orange,
      money.purple,
      money.teal,
    ];
    const field = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(28)),
      borderSide: BorderSide.none,
    );
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final sections = [...vm.sections]
          ..sort((a, b) => _groupOrder(a.$1).compareTo(_groupOrder(b.$1)));
        final bills = vm.bills;
        final totals = vm.totals;
        final noPeople = sections.isEmpty && vm.query.trim().isEmpty;
        final say = _monSay(totals, noPeople: noPeople);
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            SceneBand(
              title: 'People',
              face: say.face,
              line: say.line,
              detail: say.detail,
              compact: true,
              action: SceneIconButton(
                icon: Icons.person_add,
                tooltip: 'Add person',
                onPressed: _add,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  _BalanceCard(
                    totals: totals,
                    onSplit: () => openSplitNew(context),
                  ),
                  if (!noPeople)
                    TextField(
                      onChanged: vm.setQuery,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search people',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: scheme.surfaceContainer,
                        border: field,
                        enabledBorder: field,
                        focusedBorder: field,
                      ),
                    ),
                  if (!noPeople && sections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Nobody matches that search.',
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final (group, people) in sections)
                    _Card(
                      heading: _groupTitle(group),
                      rows: [
                        for (final summary in people)
                          _PersonRow(
                            key: ValueKey(summary.person.id),
                            summary: summary,
                            avatarColor:
                                avatarColors[jvmHash(summary.person.id) %
                                    avatarColors.length],
                          ),
                      ],
                    ),
                  if (bills.isNotEmpty)
                    _Card(
                      heading: 'Past splits',
                      rows: [
                        for (final bill in bills)
                          KobanRow(
                            key: ValueKey(bill.id),
                            title: bill.merchant ?? 'Split',
                            trailing: Text(
                              personDate(bill.billTime),
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            showChevron: true,
                            onTap: () => openSplitEdit(context, bill.id),
                            onTapLabel: 'Open',
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// They owe you first, as in the Mon's desk look.
int _groupOrder(PeopleGroup group) => switch (group) {
  PeopleGroup.owesYou => 0,
  PeopleGroup.youOwe => 1,
  PeopleGroup.others => 2,
};

({MonFace face, String line, String? detail}) _monSay(
  PeopleTotals totals, {
  required bool noPeople,
}) {
  if (noPeople) {
    return (
      face: MonFace.idle,
      line: 'No people yet.',
      detail: 'Add someone, or split a bill to start.',
    );
  }
  if (totals.owedCount > 0) {
    return (
      face: MonFace.happy,
      line: 'I will hold this.',
      detail: 'Until they pay.',
    );
  }
  if (totals.oweCount > 0) {
    return (
      face: MonFace.worry,
      line: 'You owe. I kept count.',
      detail: 'Pay it when you can.',
    );
  }
  return (
    face: MonFace.idle,
    line: 'Everyone is even.',
    detail: 'Nothing to chase.',
  );
}

/// The balance under the band, and the one gold action of the tab.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.totals, required this.onSplit});

  final PeopleTotals totals;
  final VoidCallback onSplit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final owed = totals.owedCount > 0;
    final owe = totals.oweCount > 0;
    final net = totals.owed - totals.owe;
    final label = switch (net.sign) {
      1 => owe ? 'Owed to you, after what you owe' : 'Owed to you',
      -1 => owed ? 'You owe, after what is owed to you' : 'You owe',
      _ => 'Even',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(KobanRadius.r24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          if (owed || owe) ...[
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: muted),
                  MoneyText(
                    net.sign > 0 ? '+ ${rm(net)}' : rm(net.abs()),
                    style: theme.textTheme.displayMedium,
                    color: net.sign > 0
                        ? MoneyColors.of(context).received
                        : scheme.onSurface,
                  ),
                  Text(
                    '${rm(totals.owed)} owed to you, ${rm(totals.owe)} you owe',
                    style: muted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: onSplit,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            icon: const Icon(Icons.receipt, size: 18),
            label: const Text('Split a bill'),
          ),
        ],
      ),
    );
  }
}

/// A white card with a heading and rows with a divider between them.
class _Card extends StatelessWidget {
  const _Card({required this.heading, required this.rows});

  final String heading;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(KobanRadius.r24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SectionHeading(heading),
          ),
          for (final row in rows) ...[
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            row,
          ],
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    super.key,
    required this.summary,
    required this.avatarColor,
  });

  final PersonSummary summary;
  final Color avatarColor;

  @override
  Widget build(BuildContext context) {
    final money = MoneyColors.of(context);
    final name = summary.person.name;
    final statusColor = switch (summary.balance) {
      YouPay() => money.goldText,
      PaysYou() => money.received,
      _ => null,
    };
    return KobanRow(
      title: name,
      subtitle: PeopleMath.statusLine(
        name,
        summary.balance,
        hasQr: summary.person.qrPath != null,
      ),
      subtitleColor: statusColor,
      // A tint of the color of the person under normal text keeps the initial readable in light and dark.
      leading: InitialsAvatar(name, tint: avatarColor),
      showChevron: true,
      onTap: () => openPerson(context, summary.person.id),
      onTapLabel: 'Open',
    );
  }
}

/// Asks for a name, and a QR if the owner has one. It closes with the id of the person.
/// It stays open with the message when the repository refuses the name.
class _AddPersonSheet extends StatefulWidget {
  const _AddPersonSheet({required this.vm});

  final PeopleViewModel vm;

  @override
  State<_AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends State<_AddPersonSheet> {
  var _name = '';
  String? _qrPath;
  String? _error;
  var _saving = false;
  var _picking = false;

  Future<void> _pick() async {
    if (_picking) return;
    _picking = true;
    try {
      final path = await widget.vm.pickQr();
      if (path != null && mounted) setState(() => _qrPath = path);
    } catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: s, library: 'PeopleScreen'),
      );
      if (mounted) setState(() => _error = 'Could not open your pictures.');
    } finally {
      _picking = false;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    ({String id, String? qrError})? added;
    String? error;
    try {
      added = await widget.vm.add(_name, qrPath: _qrPath);
    } on KobanUserError catch (e) {
      error = e.message;
    } catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: s, library: 'PeopleScreen'),
      );
      error = 'Could not add the person. Try again.';
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      _saving = false;
    });
    if (added != null) Navigator.pop(context, added);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = _name.trim();
    final hasQr = _qrPath != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Add person',
                style: weighted(theme.textTheme.titleLarge!, 800),
              ),
            ),
            DialogTextField(
              value: _name,
              onChanged: (v) => setState(() {
                _name = v;
                _error = null;
              }),
              label: 'Name',
              isError: _error != null,
              supportingText: _error,
              textCapitalization: TextCapitalization.words,
            ),
            Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _pick,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      spacing: 12,
                      children: [
                        Icon(Icons.qr_code_2, color: scheme.onSurfaceVariant),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasQr
                                    ? 'Payment QR'
                                    : name.isEmpty
                                    ? 'Add their payment QR'
                                    : "Add $name's payment QR",
                                style: weighted(
                                  theme.textTheme.titleSmall!,
                                  700,
                                ),
                              ),
                              Text(
                                hasQr
                                    ? 'Picture chosen.'
                                    : 'Optional. A picture from your gallery.',
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasQr)
                          Text(
                            'Replace',
                            style: weighted(
                              theme.textTheme.labelLarge!,
                              800,
                            ).copyWith(color: scheme.onSurface),
                          )
                        else
                          Icon(Icons.add, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              child: const Text('Add person'),
            ),
          ],
        ),
      ),
    );
  }
}
