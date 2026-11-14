import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../data/database.dart';
import '../../data/user_error.dart';
import '../../rules/amount_formatter.dart';
import '../../ui/dialogs.dart';
import '../../ui/kit.dart';
import 'person_view_model.dart';

final _shortDate = DateFormat('d MMM', 'en_US');
final _longDate = DateFormat('EEE, d MMM yyyy', 'en_US');

/// "3 Oct".
String personDate(int ms) =>
    _shortDate.format(DateTime.fromMillisecondsSinceEpoch(ms));

/// "RM 12.00 from Ali, 3 Oct".
String receiveText(Expense e) =>
    '${AmountFormatter.currencySymbol(e.currency)} ${AmountFormatter.formatGrouped(e.amount)} from '
    '${e.merchant ?? 'unknown'}, ${personDate(e.notificationPostTime)}';

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

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
    return 'Something went wrong. Try again.';
  }
}

Widget _cancel(BuildContext context) => TextButton(
  onPressed: () => Navigator.pop(context),
  child: const Text('Cancel'),
);

/// Asks for a new name. The dialog stays open with the message when [onSave] refuses it.
Future<void> showRenameDialog(
  BuildContext context, {
  required String name,
  required Future<void> Function(String name) onSave,
}) => showDialog<void>(
  context: context,
  builder: (_) => _RenameDialog(name: name, onSave: onSave),
);

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.name, required this.onSave});

  final String name;
  final Future<void> Function(String name) onSave;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late String _text = widget.name;
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await _attempt(() => widget.onSave(_text));
    if (!mounted) return;
    setState(() {
      _error = error;
      _saving = false;
    });
    if (error == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
    title: const Text('Rename'),
    content: DialogTextField(
      value: _text,
      onChanged: (v) => setState(() {
        _text = v;
        _error = null;
      }),
      label: 'Name',
      isError: _error != null,
      supportingText: _error,
      textCapitalization: TextCapitalization.words,
    ),
    actions: [
      _cancel(context),
      TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
    ],
  );
}

/// What the owed item dialog gives back.
enum OwedItemResult { saved, delete }

/// Adds (when [amount] is null) or edits one amount typed by hand, owed either way.
/// With [canDelete], a Delete button closes the dialog with [OwedItemResult.delete].
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

  Future<void> _save() async {
    setState(() => _saving = true);
    // An amount that does not parse goes to the repository as zero and gets its message.
    final amount = AmountFormatter.parseInput(_amountText) ?? Decimal.zero;
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
            if (widget.canDelete)
              TextButton(
                onPressed: () => Navigator.pop(context, OwedItemResult.delete),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                child: const Text('Delete'),
              ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: scheme.error)),
          ],
        ),
      ),
      actions: [
        _cancel(context),
        TextButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// A yes or no question with a Cancel button. It returns true for [confirm].
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String text,
  required String confirm,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        backgroundColor: scheme.surfaceContainer,
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: scheme.error)
                : null,
            child: Text(confirm),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

Future<bool> showSettleUpDialog(
  BuildContext context, {
  required String name,
  required int debtCount,
  required int itemCount,
}) {
  final closes = [
    if (debtCount > 0) _count(debtCount, 'split bill debt', 'split bill debts'),
    if (itemCount > 0) _count(itemCount, 'item you owe', 'items you owe'),
  ].join(' and ');
  final lock = debtCount > 0
      ? " Split bills it touches can't be edited after this."
      : '';
  return _confirm(
    context,
    title: 'Settle up with $name?',
    text: 'Closes $closes.$lock',
    confirm: 'Settle up',
  );
}

Future<bool> showDeletePersonDialog(BuildContext context, String name) =>
    _confirm(
      context,
      title: 'Delete $name?',
      text: 'Their QR and paid items are removed. Split bills keep their name.',
      confirm: 'Delete',
      destructive: true,
    );

Future<bool> showDeleteOwedItemDialog(BuildContext context, String text) =>
    _confirm(
      context,
      title: 'Delete this item?',
      text: text,
      confirm: 'Delete',
      destructive: true,
    );

/// Mark paid for one split debt: pick the received payment, or cash.
/// [onPick] gets the expense id (null for cash) and returns true when the payment starts.
/// Only then does the dialog close; otherwise it stays open, as in 0.1.1.
Future<void> showDebtPaymentDialog(
  BuildContext context,
  DebtPayment state, {
  required bool Function(String? expenseId) onPick,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    void pick(String? expenseId) {
      if (onPick(expenseId)) Navigator.pop(context);
    }

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      title: const Text('Mark paid'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in state.candidates)
              TextButton(
                onPressed: () => pick(e.id),
                child: Text(receiveText(e)),
              ),
            TextButton(
              onPressed: () => pick(null),
              child: const Text('Paid in cash'),
            ),
          ],
        ),
      ),
      actions: [_cancel(context)],
    );
  },
);
