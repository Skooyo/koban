import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../rules/amount_formatter.dart';
import '../../rules/split_math.dart';
import '../../theme/koban_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/amount_input.dart';
import '../../ui/date_labels.dart';
import '../../ui/kit.dart';
import '../../ui/undo_snack_bar.dart';
import 'split_editor_view_model.dart';

/// `RM 12.50`, grouped.
String splitRm(Decimal amount) => 'RM ${AmountFormatter.formatGrouped(amount)}';

/// The note for a linked payment that is not the receipt total, or null. The link and summary steps show it.
String? paymentNote(SplitEditorState s) {
  final total = SplitEditorViewModel.totalOf(s);
  final payment = s.linkedPayment;
  if (payment == null ||
      total == null ||
      payment.amount.compareTo(total) == 0) {
    return null;
  }
  return 'The payment is ${splitRm(payment.amount)}, the receipt is ${splitRm(total)}. '
      'Your share absorbs the difference.';
}

/// The name of a person id: Me, or the name of a person of the split.
String nameOf(SplitEditorState s, String id) => id == meId
    ? 'Me'
    : s.people.where((p) => p.id == id).firstOrNull?.name ?? id;

/// The name on an item chip: the first name, or the full name when another person
/// of the split has the same first name, so the chips stay apart.
String chipNameOf(SplitEditorState s, String name) {
  String first(String n) => n.trim().split(RegExp(r'\s+')).first.toLowerCase();
  final clash =
      ['Me', for (final p in s.people) p.name]
          .where((n) => first(n) == first(name))
          .length >
      1;
  return clash ? name.trim() : name.trim().split(RegExp(r'\s+')).first;
}

/// A white card with radius 24 on the ground of the screen.
class SplitCard extends StatelessWidget {
  const SplitCard({super.key, required this.children, this.side});

  final List<Widget> children;
  final BorderSide? side;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(KobanRadius.r24),
      side: side ?? BorderSide.none,
    ),
    child: Padding(
      padding: const EdgeInsets.all(KobanSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
}

/// A small heading inside a [SplitCard], with an optional widget at the end.
class CardHeading extends StatelessWidget {
  const CardHeading(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: theme.textTheme.titleMedium!.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Selected: a primaryContainer fill. Not selected: an outline.
class PersonChip extends StatelessWidget {
  const PersonChip(
    this.name, {
    super.key,
    required this.selected,
    this.onTap,
    this.avatar = true,
  });

  final String name;
  final bool selected;

  /// Null shows the chip as fixed: always in, not a disabled chip.
  final VoidCallback? onTap;
  final bool avatar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge!
        .copyWith(color: selected ? scheme.onPrimaryContainer : null);
    final face = avatar ? InitialsAvatar(name, size: 24) : null;
    if (onTap == null) {
      return Chip(
        avatar: face,
        label: Text(name),
        labelStyle: labelStyle,
        backgroundColor: scheme.primaryContainer,
        side: BorderSide.none,
      );
    }
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap!(),
      avatar: face,
      showCheckmark: false,
      label: Text(name),
      labelStyle: labelStyle,
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primaryContainer
            : null,
      ),
    );
  }
}

/// The linked payment: shop, time and amount.
class PaymentCard extends StatelessWidget {
  const PaymentCard(this.payment, {super.key});

  final Expense payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SplitCard(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.merchant ?? 'Payment',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    dateTimeLabel(payment.notificationPostTime),
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            MoneyText(
              splitRm(payment.amount),
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      ],
    );
  }
}

const _gap = SizedBox(height: KobanSpace.s16);

/// Who ate: Me, the people of this bill, recent people and a new name.
/// [inSheet] lays it out for the people sheet of the items step.
class PeopleStep extends StatefulWidget {
  const PeopleStep({
    super.key,
    required this.state,
    required this.vm,
    this.inSheet = false,
  });

  final SplitEditorState state;
  final SplitEditorViewModel vm;
  final bool inSheet;

  @override
  State<PeopleStep> createState() => _PeopleStepState();
}

class _PeopleStepState extends State<PeopleStep> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _add() {
    widget.vm.addPerson(_name.text);
    _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final vm = widget.vm;
    final picked = {for (final p in state.people) p.id};
    final payment = state.linkedPayment;
    return ListView(
      shrinkWrap: widget.inSheet,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (payment != null && !widget.inSheet) ...[
          PaymentCard(payment),
          const SizedBox(height: KobanSpace.s12),
        ],
        SplitCard(
          children: [
            CardHeading(
              widget.inSheet ? 'Who ate with you?' : 'Recent people',
              trailing: Text(
                'Tap to add',
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: KobanSpace.s12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                const PersonChip('Me', selected: true),
                for (final p in state.people)
                  PersonChip(
                    p.name,
                    selected: true,
                    onTap: () => vm.togglePerson(p),
                  ),
                for (final p in vm.recentPeople.where(
                  (p) => !picked.contains(p.id),
                ))
                  PersonChip(
                    p.name,
                    selected: false,
                    onTap: () => vm.togglePerson(p),
                  ),
              ],
            ),
            _gap,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(
                      labelText: 'New person',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder(
                  valueListenable: _name,
                  builder: (context, value, _) => TonalButton(
                    'Add',
                    value.text.trim().isEmpty ? null : _add,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Which payment the bill was. Radio rows, and "Paid another way".
class LinkStep extends StatelessWidget {
  const LinkStep({super.key, required this.state, required this.vm});

  final SplitEditorState state;
  final SplitEditorViewModel vm;

  // The radio group has no null value, so the empty text stands for "Paid another way".
  static const _none = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = paymentNote(state);
    final error = state.error;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        RadioGroup<String>(
          groupValue: state.selectedExpenseId ?? _none,
          onChanged: (v) =>
              vm.selectExpense(v == null || v == _none ? null : v),
          child: ListGroup(
            children: [
              for (final e in state.candidates)
                KobanRow(
                  key: ValueKey(e.id),
                  title: e.merchant ?? 'Payment',
                  subtitle: dateTimeLabel(e.notificationPostTime),
                  leading: Radio<String>(value: e.id),
                  trailing: MoneyText(splitRm(e.amount)),
                  onTap: () => vm.selectExpense(e.id),
                ),
              KobanRow(
                title: 'Paid another way',
                leading: const Radio<String>(value: _none),
                onTap: () => vm.selectExpense(null),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          _gap,
          Text(
            error,
            style: theme.textTheme.bodyLarge!.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        if (note != null) ...[_gap, ReviewNote(note)],
      ],
    );
  }
}

class ReviewNote extends StatelessWidget {
  const ReviewNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = MoneyColors.of(context).review;
    return SplitCard(
      side: BorderSide(color: review),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info, color: review, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ],
    );
  }
}

String joinNames(List<String> names) => names.length <= 1
    ? names.join(', ')
    : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

/// The people who owe the owner, for the summary line. Me is the last share line.
List<String> owingNames(SplitEditorState s) {
  final lines = SplitEditorViewModel.shareLines(s) ?? const [];
  return [
    for (final l in lines.take(lines.isEmpty ? 0 : lines.length - 1))
      if (l.$3.sign > 0) l.$2,
  ];
}

/// The shares, the total, and the actions of a saved or finished split.
/// Send summary and Save split are in the bottom bar of the screen.
class SummaryStep extends StatelessWidget {
  const SummaryStep({super.key, required this.state, required this.vm});

  final SplitEditorState state;
  final SplitEditorViewModel vm;

  /// Deletes at once. The editor closes, and the page under it shows Undo.
  Future<void> _delete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final merchant = state.merchant.trim();
    final undo = await vm.deleteSplit();
    if (undo != null) {
      showUndoSnackBar(
        messenger,
        merchant.isEmpty ? 'Split deleted' : 'Split deleted: $merchant',
        undo: undo,
      );
    }
  }

  /// "Nasi lemak, teh ais" for the items that [id] shares.
  String _itemsOf(String id) {
    final names = [
      for (final r in state.items)
        if (r.sharedBy.contains(id)) r.name.trim(),
    ];
    return names.join(', ');
  }

  /// The line under the total: do the shares add up to the printed total or the payment?
  (String, bool)? _check(Decimal total) {
    final printed = state.printedTotal;
    if (printed != null) {
      return printed.compareTo(total) == 0
          ? ('Shares add up to the printed ${splitRm(printed)}.', true)
          : (
              'Shares add up to ${splitRm(total)}. The receipt says ${splitRm(printed)}.',
              false,
            );
    }
    final payment = state.linkedPayment;
    if (payment != null && payment.amount.compareTo(total) == 0) {
      return ('Shares add up to the payment of ${splitRm(total)}.', true);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = SplitEditorViewModel.shareLines(state) ?? const [];
    final total = SplitEditorViewModel.totalOf(state);
    final amounts = state.amounts;
    final left = SplitEditorViewModel.amountsLeft(state);
    final error = state.error;
    final note = paymentNote(state);
    final saved = state.billId != null;
    final check = total == null ? null : _check(total);
    final payment = state.linkedPayment;
    // A split of a payment keeps that payment. A viewed split has nothing to save.
    final canPick =
        state.locked ||
        (!state.skipLink && (state.billId == null || state.editing));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        ListGroup(
          children: [
            for (final (id, name, amount) in lines)
              amounts == null
                  ? KobanRow(
                      title: name,
                      subtitle: [
                        id == meId ? 'Your share' : 'Owes you',
                        if (_itemsOf(id).isNotEmpty) _itemsOf(id),
                      ].join(' · '),
                      subtitleMaxLines: 2,
                      leading: InitialsAvatar(name),
                      trailing: MoneyText(splitRm(amount)),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: SplitField(
                        label: '$name (RM)',
                        value: amounts[id] ?? '',
                        onChanged: (v) => vm.setAmount(id, v),
                        keyboard: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        formatters: [AmountInput.formatter],
                      ),
                    ),
          ],
        ),
        if (amounts != null && total != null) ...[
          const SizedBox(height: 8),
          Text(
            left?.sign == 0
                ? 'Amounts add up to ${splitRm(total)}'
                : left == null
                ? 'Type an amount for everyone'
                : left.sign > 0
                ? '${splitRm(left)} left to share'
                : '${splitRm(-left)} more than the total',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: left?.sign == 0
                  ? scheme.onSurfaceVariant
                  : MoneyColors.of(context).review,
            ),
          ),
        ],
        if (total != null) ...[
          const SizedBox(height: KobanSpace.s12),
          ListGroup(
            children: [
              KobanRow(
                title: 'Total',
                trailing: MoneyText(
                  splitRm(total),
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: KobanSpace.s12),
        ListGroup(
          children: [
            KobanRow(
              title: 'Payment',
              subtitle: payment == null
                  ? 'Paid another way'
                  : '${payment.merchant ?? 'Payment'} · ${splitRm(payment.amount)}',
              showChevron: canPick,
              onTap: canPick && !state.saving ? vm.changePayment : null,
            ),
          ],
        ),
        if (check != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                check.$2 ? Icons.check : Icons.warning,
                size: 18,
                color: check.$2
                    ? scheme.onSurfaceVariant
                    : MoneyColors.of(context).review,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  check.$1,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (note != null) ...[_gap, ReviewNote(note)],
        if (error != null) ...[
          _gap,
          Text(
            error,
            style: theme.textTheme.bodyLarge!.copyWith(color: scheme.error),
          ),
        ],
        _gap,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Change amounts replaces the items, so only a one-item split offers it.
            if (!state.locked && lines.isNotEmpty && state.items.length == 1)
              TextButton(
                onPressed: state.saving
                    ? null
                    : amounts == null
                    ? vm.changeAmounts
                    : vm.splitAmountsEvenly,
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: Text(
                  amounts == null ? 'Change amounts' : 'Split evenly',
                ),
              ),
            if (saved && !state.locked)
              TextButton.icon(
                onPressed: state.saving ? null : vm.editItems,
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit items'),
              ),
          ],
        ),
        if (saved) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: state.saving ? null : () => _delete(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              foregroundColor: scheme.error,
            ),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete split'),
          ),
        ],
      ],
    );
  }
}

/// An outlined one-line text field. It shows [value] again when the state changes it.
class SplitField extends StatefulWidget {
  const SplitField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboard,
    this.hint,
    this.isError = false,
    this.formatters,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboard;
  final String? hint;
  final bool isError;
  final List<TextInputFormatter>? formatters;

  @override
  State<SplitField> createState() => _SplitFieldState();
}

class _SplitFieldState extends State<SplitField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(SplitField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    onChanged: widget.onChanged,
    keyboardType: widget.keyboard,
    inputFormatters: widget.formatters,
    decoration: InputDecoration(
      labelText: widget.label,
      border: const OutlineInputBorder(),
      helperText: widget.isError ? null : widget.hint,
      helperMaxLines: 2,
      errorText: widget.isError ? (widget.hint ?? '') : null,
    ),
  );
}
