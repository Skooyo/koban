import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../data/people_repository.dart';
import '../../data/user_error.dart';
import '../../rules/people_math.dart';
import '../../theme/koban_theme.dart';
import '../../ui/kit.dart';
import '../person/person_dialogs.dart' show personDate;
import 'people_view_model.dart';

String _groupTitle(PeopleGroup group) => switch (group) {
  PeopleGroup.youOwe => 'You owe',
  PeopleGroup.owesYou => 'Owes you',
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
    final id = await showDialog<String>(
      context: context,
      builder: (_) => _AddPersonDialog(onAdd: _vm!.add),
    );
    if (id != null && mounted) await openPerson(context, id);
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
        final sections = vm.sections;
        final bills = vm.bills;
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 112),
              children: [
                const LargeTopBar(
                  title: 'People',
                  subtitle: 'Payment QRs, and what you owe each other',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: vm.setQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search people',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: field,
                      enabledBorder: field,
                      focusedBorder: field,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                  child: TonalButton(
                    'Split a bill',
                    () => openSplitNew(context),
                    icon: Icons.receipt,
                  ),
                ),
                if (sections.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                    ),
                    child: Text(
                      vm.query.trim().isEmpty
                          ? 'No people yet. Add someone, or split a bill to start.'
                          : 'Nobody matches that search.',
                      style: theme.textTheme.bodyLarge!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final (group, people) in sections)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeading(_groupTitle(group)),
                        ListGroup(
                          children: [
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
                      ],
                    ),
                  ),
                if (bills.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeading('Past splits'),
                        ListGroup(
                          children: [
                            for (final bill in bills)
                              KobanRow(
                                key: ValueKey(bill.id),
                                title: bill.merchant ?? 'Split bill',
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
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: _add,
                icon: const Icon(Icons.person_add),
                label: const Text('Add person'),
                extendedTextStyle: weighted(theme.textTheme.titleMedium!, 700),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
            ),
          ],
        );
      },
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

/// Asks for a name. It closes with the id of the person.
/// It stays open with the message when the repository refuses the name.
class _AddPersonDialog extends StatefulWidget {
  const _AddPersonDialog({required this.onAdd});

  final Future<String> Function(String name) onAdd;

  @override
  State<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<_AddPersonDialog> {
  var _name = '';
  String? _error;
  var _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    String? id;
    String? error;
    try {
      id = await widget.onAdd(_name);
    } on KobanUserError catch (e) {
      error = e.message;
    } catch (e, s) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: s, library: 'PeopleScreen'),
      );
      error = 'Something went wrong. Try again.';
    }
    if (!mounted) return;
    setState(() {
      _error = error;
      _saving = false;
    });
    if (id != null) Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
    title: const Text('Add person'),
    content: DialogTextField(
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _saving ? null : _save, child: const Text('Add')),
    ],
  );
}
