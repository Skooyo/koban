import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:material_ui/material_ui.dart';

import '../../data/database.dart';
import '../../rules/amount_formatter.dart';
import '../../rules/split_math.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
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

/// Selected: a primaryContainer fill with a check. Not selected: an outline.
class _PersonChip extends StatelessWidget {
  const _PersonChip(this.name, {required this.selected, this.onTap});

  final String name;
  final bool selected;

  /// Null shows the chip as fixed.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      selected: selected,
      onSelected: onTap == null ? null : (_) => onTap!(),
      label: Text(name),
      labelStyle: Theme.of(context).textTheme.labelLarge!
          .copyWith(color: selected ? scheme.onPrimaryContainer : null),
      checkmarkColor: scheme.onPrimaryContainer,
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primaryContainer
            : null,
      ),
    );
  }
}

class _StepIntro extends StatelessWidget {
  const _StepIntro(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium!.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.intro);

  final String title;
  final String intro;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
      const SizedBox(height: 8),
      _StepIntro(intro),
    ],
  );
}

const _gap = SizedBox(height: 16);

/// Who shares the bill: Me, the people of this bill, recent people and a new name.
class PeopleStep extends StatefulWidget {
  const PeopleStep({super.key, required this.state, required this.vm});

  final SplitEditorState state;
  final SplitEditorViewModel vm;

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
    final state = widget.state;
    final vm = widget.vm;
    final picked = {for (final p in state.people) p.id};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Heading('Who is sharing?', 'Tap a name to add or remove it.'),
        _gap,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const _PersonChip('Me', selected: true),
            for (final p in state.people)
              _PersonChip(
                p.name,
                selected: true,
                onTap: () => vm.togglePerson(p),
              ),
            for (final p in vm.recentPeople.where(
              (p) => !picked.contains(p.id),
            ))
              _PersonChip(
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
              builder: (context, value, _) =>
                  TonalButton('Add', value.text.trim().isEmpty ? null : _add),
            ),
          ],
        ),
      ],
    );
  }
}

/// Who had what: a card for each item with a chip for each person.
class AssignStep extends StatelessWidget {
  const AssignStep({super.key, required this.state, required this.vm});

  final SplitEditorState state;
  final SplitEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final missing = SplitEditorViewModel.unassigned(state);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _StepIntro(
          'Tap names to share each item. A shared item splits evenly.',
        ),
        _gap,
        Align(
          alignment: Alignment.centerLeft,
          child: TonalButton(
            'Split everything evenly',
            vm.splitEverythingEvenly,
          ),
        ),
        for (final row in state.items) ...[
          _gap,
          _AssignCard(
            key: ValueKey(row.key),
            row: row,
            people: state.people,
            unassigned: missing.contains(row.key),
            vm: vm,
          ),
        ],
      ],
    );
  }
}

class _AssignCard extends StatelessWidget {
  const _AssignCard({
    super.key,
    required this.row,
    required this.people,
    required this.unassigned,
    required this.vm,
  });

  final ItemRow row;
  final List<SplitPeopleData> people;
  final bool unassigned;
  final SplitEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quantity = row.quantity.trim();
    final price = AmountFormatter.parseInput(row.price);
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: unassigned
            ? BorderSide(color: MoneyColors.of(context).review, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quantity == '1' ? row.name : '${row.name} ×$quantity',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (price != null) ...[
                  const SizedBox(width: 12),
                  MoneyText(splitRm(price), style: theme.textTheme.titleMedium),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PersonChip(
                  'Everyone',
                  selected: row.sharedBy.length == people.length + 1,
                  onTap: () => vm.toggleEveryone(row.key),
                ),
                _PersonChip(
                  'Me',
                  selected: row.sharedBy.contains(meId),
                  onTap: () => vm.toggleShare(row.key, meId),
                ),
                for (final p in people)
                  _PersonChip(
                    p.name,
                    selected: row.sharedBy.contains(p.id),
                    onTap: () => vm.toggleShare(row.key, p.id),
                  ),
              ],
            ),
            if (unassigned) ...[
              const SizedBox(height: 12),
              Text(
                'Pick who had this item.',
                style: theme.textTheme.bodySmall!.copyWith(
                  color: MoneyColors.of(context).review,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Which card payment the bill was. Radio rows, and "Not paid by card".
class LinkStep extends StatelessWidget {
  const LinkStep({super.key, required this.state, required this.vm});

  final SplitEditorState state;
  final SplitEditorViewModel vm;

  // The radio group has no null value, so the empty text stands for "Not paid by card".
  static const _none = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = paymentNote(state);
    final error = state.error;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Heading(
          'Which payment was this?',
          'Link the card payment, so your spending counts only your share.',
        ),
        _gap,
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
                title: 'Not paid by card',
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
        if (note != null) ...[_gap, _ReviewNote(note)],
      ],
    );
  }
}

class _ReviewNote extends StatelessWidget {
  const _ReviewNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = MoneyColors.of(context).review;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: review),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info, color: review, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

String _joinNames(List<String> names) => names.length <= 1
    ? names.join(', ')
    : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';

/// The shares, the total, and the actions of a saved or finished split.
class SummaryStep extends StatelessWidget {
  const SummaryStep({
    super.key,
    required this.state,
    required this.vm,
    required this.onShare,
  });

  final SplitEditorState state;
  final SplitEditorViewModel vm;
  final ValueChanged<String> onShare;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = SplitEditorViewModel.shareLines(state) ?? const [];
    final total = SplitEditorViewModel.totalOf(state);
    final amounts = state.amounts;
    final left = SplitEditorViewModel.amountsLeft(state);
    // The last line is always Me. Everyone before it with a share owes the owner.
    final owing = [
      for (final l in lines.take(lines.isEmpty ? 0 : lines.length - 1))
        if (l.$3.sign > 0) l.$2,
    ];
    final error = state.error;
    final note = paymentNote(state);
    final saved = state.billId != null;
    final edit = state.locked
        ? ('Change payment', vm.changePayment)
        : ('Edit items', vm.editItems);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Mon(MonFace.happy, size: 56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Split done',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  if (state.locked)
                    const _StepIntro(
                      "Someone has paid you back, so the items can't change.",
                    )
                  else if (owing.isNotEmpty)
                    _StepIntro(
                      '${_joinNames(owing)} now ${owing.length == 1 ? 'owes' : 'owe'} you.',
                    ),
                ],
              ),
            ),
          ],
        ),
        _gap,
        ListGroup(
          children: [
            for (final (id, name, amount) in lines)
              amounts == null
                  ? KobanRow(
                      title: name,
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
          _gap,
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
        if (note != null) ...[_gap, _ReviewNote(note)],
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
            TonalButton('Share summary', () {
              final text = SplitEditorViewModel.shareText(state);
              if (text != null) onShare(text);
            }, icon: Icons.share),
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
            if (saved)
              TextButton.icon(
                onPressed: state.saving ? null : edit.$2,
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.edit, size: 18),
                label: Text(edit.$1),
              ),
          ],
        ),
        if (saved) ...[
          _gap,
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
      errorText: widget.isError ? (widget.hint ?? '') : null,
    ),
  );
}
