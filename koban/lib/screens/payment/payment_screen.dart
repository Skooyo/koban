import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../data/category_repository.dart';
import '../../rules/types.dart';
import '../../theme/koban_theme.dart';
import '../../ui/amount_input.dart';
import '../../ui/date_labels.dart';
import '../../ui/dialogs.dart';
import '../../ui/kit.dart';
import 'category_sheet.dart';
import 'payment_view_model.dart';

const _padRows = ['123', '456', '789', '.0<'];

/// The add and edit page of a payment. It closes with a [PaymentResult],
/// or with null when the owner leaves without saving.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, this.expenseId});

  final String? expenseId;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final AppServices _s;
  late final PaymentViewModel _vm;
  bool _ready = false;
  bool _shopFocused = false;
  bool _noteFocused = false;
  // Add opens with the pad. Edit opens without it until the amount is tapped.
  late bool _padRequested = widget.expenseId == null;
  bool _wasKeyboardUp = false;
  bool _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready) {
      _ready = true;
      _s = AppScope.of(context);
      _vm = PaymentViewModel(_s, expenseId: widget.expenseId)
        ..addListener(_closeIfMissing);
    }
    // Back or Done hides the keyboard but leaves focus in Shop or Note.
    // Drop it so the number pad comes back.
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (_wasKeyboardUp && !keyboardUp) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (!_vm.isEditing) _padRequested = true;
    }
    _wasKeyboardUp = keyboardUp;
  }

  @override
  void dispose() {
    _vm
      ..removeListener(_closeIfMissing)
      ..dispose();
    super.dispose();
  }

  void _closeIfMissing() {
    final r = _vm.closeNow;
    if (r != null) _close(r);
  }

  void _close(PaymentResult? result) {
    // Back during a save already popped the sheet. A second pop would close the page under it.
    if (_closing || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _closing = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _save() async {
    final r = await _vm.save();
    if (r != null) _close(r);
  }

  Future<void> _delete() async {
    final r = await _vm.delete();
    if (r != null) _close(r);
  }

  /// Ask first when there is typed data. A save never asks: it sets `saving` first.
  Future<void> _leave() async {
    if (_vm.saving) return;
    if (!_vm.hasChanges || await showDiscardChangesDialog(context)) {
      _close(null);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surfaceContainer,
          title: const Text('Delete this payment?'),
          content: const Text('It will no longer count in your totals.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (ok == true) await _delete();
  }

  Future<void> _pickDate(PaymentForm f) async {
    final picked = await showPastDatePicker(
      context,
      time: f.postTime,
      now: _s.now(),
    );
    if (picked != null) _vm.setDate(picked);
  }

  void _showPad() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _padRequested = true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_vm, _s.inGroups]),
      builder: (context, _) {
        final f = _vm.form;
        // While an edited payment loads, or when it is missing, the page is empty.
        if (f == null) return const Scaffold();
        return PopScope(
          canPop: !_vm.hasChanges || _vm.saving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leave();
          },
          child: Scaffold(body: SafeArea(child: _content(context, f))),
        );
      },
    );
  }

  Widget _content(BuildContext context, PaymentForm f) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final income = f.type == TransactionType.receive;
    final editing = _vm.isEditing;
    final valid = AmountInput.toAmount(f.amountText) != null;
    final padVisible = _padRequested && !_shopFocused && !_noteFocused;
    final categoryName = _vm.categories
        .where((c) => c.id == f.categoryId)
        .map((c) => c.name)
        .firstOrNull;
    final amount = 'RM ${f.amountText.isEmpty ? '0' : f.amountText}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _TopRow(
            type: f.type,
            editing: editing,
            onClose: _leave,
            onType: _vm.setType,
            onDelete: _vm.saving ? null : _confirmDelete,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    excludeSemantics: true,
                    button: true,
                    label: f.amountText.isEmpty
                        ? 'Amount empty'
                        : 'Amount RM ${f.amountText}',
                    onTapHint: 'Type the amount',
                    onTap: _showPad,
                    child: InkWell(
                      onTap: _showPad,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            MoneyText(
                              income ? '+ $amount' : amount,
                              style: theme.textTheme.displayLarge,
                              color: income
                                  ? MoneyColors.of(context).received
                                  : f.amountText.isEmpty
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                            ),
                            Text(
                              editing
                                  ? '${income ? 'Received' : 'Spent'} · ${dateTimeLabel(f.postTime)}'
                                  : 'Tap a number to change it',
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListGroup(
                    children: [
                      KobanRow(
                        title:
                            categoryName ??
                            CategoryRepository.uncategorizedName,
                        subtitle: 'Category',
                        leading: CategoryDot(
                          categoryColor(context, f.categoryId),
                          size: 12,
                        ),
                        showChevron: true,
                        onTap: () => showCategorySheet(
                          context,
                          categories: _vm.categories,
                          selectedId: f.categoryId,
                          onPick: _vm.setCategory,
                        ),
                        onTapLabel: 'Change category',
                      ),
                      KobanRow(
                        title: dateLabel(f.postTime, _s.now()),
                        subtitle: 'Date',
                        leading: const Icon(Icons.calendar_month),
                        showChevron: true,
                        onTap: () => _pickDate(f),
                        onTapLabel: 'Change date',
                      ),
                      _TextRow(
                        label: 'Shop',
                        placeholder: 'Not set',
                        icon: Icons.storefront,
                        value: f.merchant,
                        onChanged: _vm.setMerchant,
                        onFocus: (on) => setState(() {
                          _shopFocused = on;
                          if (on) _padRequested = false;
                        }),
                        singleLine: true,
                      ),
                      _TextRow(
                        label: 'Note',
                        placeholder: 'Optional',
                        icon: Icons.edit_note,
                        value: f.notes,
                        onChanged: _vm.setNotes,
                        onFocus: (on) => setState(() {
                          _noteFocused = on;
                          if (on) _padRequested = false;
                        }),
                        singleLine: false,
                      ),
                    ],
                  ),
                  if (_vm.inGroups && !income) ...[
                    const SizedBox(height: 12),
                    ListGroup(
                      children: [
                        KobanRow(
                          title: 'Count in group totals',
                          subtitle: f.privateToGroups
                              ? 'Group members do not see this payment'
                              : 'Group members see this in your totals',
                          trailing: ExcludeSemantics(
                            child: IgnorePointer(
                              child: Switch(
                                value: !f.privateToGroups,
                                onChanged: (_) {},
                              ),
                            ),
                          ),
                          onTap: () =>
                              _vm.setPrivateToGroups(!f.privateToGroups),
                        ),
                      ],
                    ),
                  ],
                  if (f.categoryId != null &&
                      f.categoryId != _vm.loadedCategoryId &&
                      f.merchant.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'A new category also applies to past payments from this shop',
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (padVisible)
            _NumberPad(onKey: _vm.press, onBackspace: _vm.backspace),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: FilledButton(
                onPressed: valid ? _save : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      editing ? 'Save changes' : 'Save payment',
                      style: weighted(theme.textTheme.titleMedium!, 700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.type,
    required this.editing,
    required this.onClose,
    required this.onType,
    required this.onDelete,
  });

  final TransactionType type;
  final bool editing;
  final VoidCallback onClose;
  final ValueChanged<TransactionType> onType;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                tooltip: 'Close',
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 8),
              if (editing) ...[
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Payment', style: theme.textTheme.titleLarge),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  tooltip: 'Delete payment',
                  icon: Icon(Icons.delete, color: theme.colorScheme.error),
                ),
              ] else
                Expanded(
                  child: DirectionSegments(selected: type, onPick: onType),
                ),
            ],
          ),
          // Edit keeps the Spent and Received switch under the title row.
          if (editing) ...[
            const SizedBox(height: 8),
            DirectionSegments(selected: type, onPick: onType),
          ],
        ],
      ),
    );
  }
}

/// A [KobanRow]-shaped row whose title is typed in place. A tap on the row types.
class _TextRow extends StatefulWidget {
  const _TextRow({
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.onFocus,
    required this.singleLine,
  });

  final String label;
  final String placeholder;
  final IconData icon;
  final String value;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onFocus;
  final bool singleLine;

  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  late final _controller = TextEditingController(text: widget.value);
  late final _focus = FocusNode()..addListener(_focusChanged);

  void _focusChanged() => widget.onFocus(_focus.hasFocus);

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.titleMedium!.copyWith(
      color: theme.colorScheme.onSurface,
    );
    return InkWell(
      onTap: _focus.requestFocus,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Center(child: Icon(widget.icon, color: muted)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: widget.label,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        onChanged: widget.onChanged,
                        onSubmitted: (_) => _focus.unfocus(),
                        style: style,
                        cursorColor: theme.colorScheme.primary,
                        minLines: 1,
                        maxLines: widget.singleLine ? 1 : 4,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: widget.singleLine
                            ? TextInputAction.done
                            : TextInputAction.newline,
                        keyboardType: widget.singleLine
                            ? TextInputType.text
                            : TextInputType.multiline,
                        decoration: InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: widget.placeholder,
                          hintStyle: style.copyWith(color: muted),
                        ),
                      ),
                    ),
                    Text(
                      widget.label,
                      style: theme.textTheme.bodyMedium!.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.keyboard_arrow_right, color: muted, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.onKey, required this.onBackspace});

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          for (final row in _padRows)
            Padding(
              padding: EdgeInsets.only(top: row == _padRows.first ? 0 : 8),
              child: Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: switch (row[i]) {
                          '.' => 'Decimal point',
                          '<' => 'Delete digit',
                          _ => null,
                        },
                        excludeSemantics: row[i] == '.' || row[i] == '<',
                        child: Material(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () =>
                                row[i] == '<' ? onBackspace() : onKey(row[i]),
                            child: SizedBox(
                              height: 52,
                              child: Center(
                                child: row[i] == '<'
                                    ? const Icon(Icons.backspace)
                                    : Text(
                                        row[i],
                                        style: weighted(
                                          theme.textTheme.titleLarge!,
                                          700,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
