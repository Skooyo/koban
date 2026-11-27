import 'dart:async';
import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../data/database.dart';
import '../../data/qr_store.dart';
import '../../data/undoable.dart';
import '../../data/user_error.dart';
import '../../rules/amount_formatter.dart';
import '../../rules/people_math.dart';
import '../../ui/dialogs.dart';
import '../../ui/kit.dart';
import '../../ui/money.dart';
import '../../ui/sheets.dart';
import '../../theme/koban_theme.dart';
import 'person_view_model.dart';
import 'qr_widgets.dart';

final _shortDate = DateFormat('d MMM', 'en_US');
final _dayDate = DateFormat('EEE, d MMM', 'en_US');
final _longDate = DateFormat('EEE, d MMM yyyy', 'en_US');

/// "3 Oct".
String personDate(int ms) =>
    _shortDate.format(DateTime.fromMillisecondsSinceEpoch(ms));

/// "RM 12.00 from Ali, 3 Oct".
String receiveText(Expense e) =>
    '${AmountFormatter.currencySymbol(e.currency)} ${AmountFormatter.formatGrouped(e.amount)} from '
    '${e.merchant ?? 'unknown'}, ${personDate(e.notificationPostTime)}';

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// "a", "a and b", "a, b and c", "a, b, c and 2 more".
String _names(List<String> names) {
  if (names.length > 3) {
    return '${names.take(3).join(', ')} and ${names.length - 3} more';
  }
  return names.length < 2
      ? names.join()
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

/// Runs [save]. It returns null when the save worked, or else the message for the dialog.
Future<String?> _attempt(Future<void> Function() save) async {
  try {
    await save();
    return null;
  } on KobanUserError catch (e) {
    return e.message;
  } catch (e, s) {
    developer.log(
      'Save failed',
      name: 'PersonDialogs',
      error: e,
      stackTrace: s,
    );
    return 'Could not save the change. Try again.';
  }
}

Widget _cancel(BuildContext context) => TextButton(
  onPressed: () => Navigator.pop(context),
  style: TextButton.styleFrom(
    minimumSize: const Size(0, 48),
    foregroundColor: Theme.of(context).colorScheme.onSurface,
  ),
  child: const Text('Cancel'),
);

/// What the Edit person sheet gives back.
enum EditPersonResult { saved, delete }

/// One sheet for the name, the QR and Delete person. Save changes renames the person.
/// The sheet stays open with the message when the repository refuses the name.
/// Delete person closes it with [EditPersonResult.delete].
Future<EditPersonResult?> showEditPersonSheet(
  BuildContext context, {
  required PersonViewModel vm,
}) => showKobanSheet<EditPersonResult>(
  context: context,
  builder: (_) => _EditPersonSheet(vm: vm),
);

class _EditPersonSheet extends StatefulWidget {
  const _EditPersonSheet({required this.vm});

  final PersonViewModel vm;

  @override
  State<_EditPersonSheet> createState() => _EditPersonSheetState();
}

class _EditPersonSheetState extends State<_EditPersonSheet> {
  late String _name = widget.vm.detail?.person.name ?? '';
  String? _error;
  bool _saving = false;
  // The Undo snackbar of the page sits behind this sheet, so a replace shows its Undo here.
  String? _qrNote;
  Undoable? _qrUndo;

  @override
  void initState() {
    super.initState();
    widget.vm.clearQrNotices();
  }

  @override
  void dispose() {
    // The sheet closed with Undo still open: the old picture can go.
    unawaited(_qrUndo?.commit?.call());
    super.dispose();
  }

  Future<void> _replaceQr(String name) async {
    final vm = widget.vm;
    final path = await chooseQrPicture(
      context,
      name: name,
      pick: vm.pickQr,
      discard: vm.discardPick,
    );
    if (path == null) return;
    final (:saved, :undo) = await vm.replaceQr(path);
    if (!mounted || !saved) return;
    setState(() {
      _qrNote = undo == null ? 'QR added.' : 'QR replaced.';
      _qrUndo = undo;
    });
  }

  Future<void> _undoQr() async {
    final undo = _qrUndo;
    if (undo == null) return;
    setState(() => _qrUndo = null);
    try {
      await undo.undo();
      if (mounted) setState(() => _qrNote = 'Old QR put back.');
    } catch (e, s) {
      developer.log(
        'Undo failed',
        name: 'PersonDialogs',
        error: e,
        stackTrace: s,
      );
      if (mounted) setState(() => _qrNote = 'Could not put the old QR back.');
    }
  }

  Future<void> _save() async {
    final current = widget.vm.detail?.person.name;
    if (_name.trim() == current) {
      Navigator.pop(context, EditPersonResult.saved);
      return;
    }
    setState(() => _saving = true);
    final error = await _attempt(() => widget.vm.rename(_name));
    if (!mounted) return;
    setState(() {
      _error = error;
      _saving = false;
    });
    if (error == null) Navigator.pop(context, EditPersonResult.saved);
  }

  /// Delete person drops a typed name, so it asks first.
  Future<void> _delete() async {
    final current = widget.vm.detail?.person.name;
    if (_name.trim() != current && !await showDiscardChangesDialog(context)) {
      return;
    }
    if (mounted) Navigator.pop(context, EditPersonResult.delete);
  }

  /// Why Delete person is off, or null when the person has nothing open.
  String? _whyNoDelete(String name, Balance balance) => switch (balance) {
    PaysYou(:final amount) => 'Settle up first. $name owes you ${rm(amount)}.',
    YouPay(:final amount) => 'Settle up first. You owe $name ${rm(amount)}.',
    Even() => 'Mark each item paid first.',
    AllPaid() => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final detail = widget.vm.detail;
        if (detail == null) return const LoadingLine();
        final name = detail.person.name;
        final hasQr = detail.person.qrPath != null;
        final why = _whyNoDelete(name, detail.balance);
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
                    'Edit $name',
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [
                    Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        spacing: 12,
                        children: [
                          if (hasQr)
                            QrThumb(
                              image: qrImage(detail.person.qrPath!),
                              version: widget.vm.qrVersion,
                            )
                          else
                            Icon(
                              Icons.qr_code_2,
                              color: scheme.onSurfaceVariant,
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment QR',
                                  style: weighted(
                                    theme.textTheme.titleSmall!,
                                    700,
                                  ),
                                ),
                                Text(
                                  hasQr
                                      ? qrAddedText(
                                          widget.vm.qrAddedAt,
                                          AppScope.of(context).now(),
                                        )
                                      : 'Not added yet',
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _replaceQr(name),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              foregroundColor: scheme.onSurface,
                            ),
                            child: Text(hasQr ? 'Replace QR' : 'Add QR'),
                          ),
                        ],
                      ),
                    ),
                    if (widget.vm.qrError case final error?)
                      Text(error, style: TextStyle(color: scheme.error))
                    else if (_qrNote case final note?)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              note,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (_qrUndo != null)
                            TextButton(
                              onPressed: _undoQr,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              child: const Text('Undo'),
                            ),
                        ],
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: why == null ? _delete : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        foregroundColor: scheme.error,
                      ),
                      child: const Text('Delete person'),
                    ),
                    if (why != null)
                      Text(
                        why,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                  child: const Text('Save changes'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// What the owed item dialog gives back.
enum OwedItemResult { saved, delete }

/// Adds (when [amount] is null) or edits one amount typed by hand, owed either way.
/// With [canDelete], a Delete button at the left end of the button row closes the dialog
/// with [OwedItemResult.delete]. Save stays off until the amount is above zero.
Future<OwedItemResult?> showOwedItemDialog(
  BuildContext context, {
  required String title,
  required Future<void> Function(
    String description,
    Decimal amount,
    int itemDate,
  )
  onSave,
  bool canDelete = false,
  String description = '',
  Decimal? amount,
  int? itemDate,
}) {
  final now = AppScope.of(context).now;
  return showDialog<OwedItemResult>(
    context: context,
    builder: (_) => _OwedItemDialog(
      title: title,
      onSave: onSave,
      canDelete: canDelete,
      description: description,
      amount: amount,
      itemDate: itemDate ?? now().millisecondsSinceEpoch,
      now: now,
    ),
  );
}

class _OwedItemDialog extends StatefulWidget {
  const _OwedItemDialog({
    required this.title,
    required this.onSave,
    required this.canDelete,
    required this.description,
    required this.amount,
    required this.itemDate,
    required this.now,
  });

  final String title;
  final Future<void> Function(String, Decimal, int) onSave;
  final bool canDelete;
  final String description;
  final Decimal? amount;
  final int itemDate;
  final DateTime Function() now;

  @override
  State<_OwedItemDialog> createState() => _OwedItemDialogState();
}

class _OwedItemDialogState extends State<_OwedItemDialog> {
  late String _description = widget.description;
  late String _amountText = widget.amount == null
      ? ''
      : AmountFormatter.formatDisplay(widget.amount!);
  late int _itemDate = widget.itemDate;
  String? _error;
  bool _saving = false;
  bool _pickingDate = false;

  Decimal? get _amount {
    final amount = AmountFormatter.parseInput(_amountText);
    return amount != null && amount.sign > 0 ? amount : null;
  }

  Future<void> _save() async {
    final amount = _amount;
    if (amount == null) return;
    setState(() => _saving = true);
    final error = await _attempt(
      () => widget.onSave(_description, amount, _itemDate),
    );
    if (!mounted) return;
    setState(() {
      _error = error;
      _saving = false;
    });
    if (error == null) Navigator.pop(context, OwedItemResult.saved);
  }

  Future<void> _pickDate() async {
    if (_pickingDate) return;
    _pickingDate = true;
    final picked = await showPastDatePicker(
      context,
      time: _itemDate,
      now: widget.now(),
    );
    _pickingDate = false;
    if (picked != null && mounted) setState(() => _itemDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final save = TextButton(
      onPressed: _saving || _amount == null ? null : _save,
      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
      child: const Text('Save'),
    );
    return AlertDialog(
      backgroundColor: scheme.surfaceContainer,
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            DialogTextField(
              value: _description,
              onChanged: (v) => setState(() {
                _description = v;
                _error = null;
              }),
              label: 'What for',
              textCapitalization: TextCapitalization.sentences,
            ),
            DialogTextField(
              value: _amountText,
              onChanged: (v) => setState(() {
                _amountText = v;
                _error = null;
              }),
              label: 'Amount',
              prefixText: 'RM ',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            Material(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Semantics(
                button: true,
                onTapHint: 'Pick date',
                child: InkWell(
                  onTap: _pickDate,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.date_range,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _longDate.format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      _itemDate,
                                    ),
                                  ),
                                  style: theme.textTheme.titleSmall,
                                ),
                                Text(
                                  'Date',
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_right,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ),
      ),
      actionsAlignment: widget.canDelete
          ? MainAxisAlignment.spaceBetween
          : null,
      actions: widget.canDelete
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context, OwedItemResult.delete),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: scheme.error,
                ),
                child: const Text('Delete'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [_cancel(context), save],
              ),
            ]
          : [_cancel(context), save],
    );
  }
}

/// Asks to settle up. It shows who pays whom and how much, and what it closes.
/// [splits] and [items] are labels with a date, so two of them never read the same.
/// It returns true for Settle up.
Future<bool> showSettleUpDialog(
  BuildContext context, {
  required String name,
  required Balance balance,
  required List<String> splits,
  required List<String> items,
}) async {
  final closes = [
    if (splits.isNotEmpty)
      '${_count(splits.length, 'split', 'splits')}: ${_names(splits)}',
    if (items.isNotEmpty)
      '${_count(items.length, 'item', 'items')}: ${_names(items)}',
  ].join('; ');
  final (figure, who) = switch (balance) {
    PaysYou(:final amount) => (
      '+ ${rm(amount)}',
      '$name pays you ${rm(amount)}.',
    ),
    YouPay(:final amount) => (rm(amount), 'You pay $name ${rm(amount)}.'),
    _ => ('', ''),
  };
  final lock = splits.isNotEmpty
      ? ' You cannot change their items after this.'
      : '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return AlertDialog(
        backgroundColor: scheme.surfaceContainer,
        title: Text('Settle up with $name?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              MoneyText(
                figure,
                style: theme.textTheme.headlineMedium,
                color: balance is PaysYou
                    ? MoneyColors.of(context).received
                    : scheme.onSurface,
              ),
              Text('$who This closes $closes.$lock'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: scheme.onSurface,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Settle up'),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// Mark paid for one split debt: pick the received payment, or cash, then Mark paid.
/// [onPick] gets the expense id (null for cash) and returns true when the payment starts.
/// Only then does the dialog close; otherwise it stays open, as in 0.1.1.
Future<void> showDebtPaymentDialog(
  BuildContext context,
  DebtPayment state, {
  required bool Function(String? expenseId) onPick,
}) => showDialog<void>(
  context: context,
  builder: (_) => _DebtPaymentDialog(state: state, onPick: onPick),
);

class _DebtPaymentDialog extends StatefulWidget {
  const _DebtPaymentDialog({required this.state, required this.onPick});

  final DebtPayment state;
  final bool Function(String? expenseId) onPick;

  @override
  State<_DebtPaymentDialog> createState() => _DebtPaymentDialogState();
}

class _DebtPaymentDialogState extends State<_DebtPaymentDialog> {
  // The first payment is the likeliest match. Without one, the choice is cash.
  late String? _expenseId = widget.state.candidates.firstOrNull?.id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final view = widget.state.debt;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainer,
      title: Text('Mark ${rm(view.debt.amount)} paid'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${view.billMerchant ?? 'Split'}, '
                '${_dayDate.format(DateTime.fromMillisecondsSinceEpoch(view.billTime))}. '
                'How did ${view.personName} pay?',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final e in widget.state.candidates)
              _ChoiceRow(
                title:
                    '${AmountFormatter.currencySymbol(e.currency)} '
                    '${AmountFormatter.formatGrouped(e.amount)} received',
                subtitle:
                    '${_dayDate.format(DateTime.fromMillisecondsSinceEpoch(e.notificationPostTime))}'
                    ' · ${e.merchant ?? 'no name'}',
                selected: _expenseId == e.id,
                onTap: () => setState(() => _expenseId = e.id),
              ),
            _ChoiceRow(
              title: 'Paid in cash',
              selected: _expenseId == null,
              onTap: () => setState(() => _expenseId = null),
            ),
          ],
        ),
      ),
      actions: [
        _cancel(context),
        TextButton(
          onPressed: () {
            if (widget.onPick(_expenseId)) Navigator.pop(context);
          },
          style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
          child: const Text('Mark paid'),
        ),
      ],
    );
  }
}

/// One radio choice: a filled or empty circle, a title and an optional second line.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                spacing: 12,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: scheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: weighted(theme.textTheme.titleSmall!, 700),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
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
