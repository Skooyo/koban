import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../rules/types.dart';
import '../../theme/koban_theme.dart';
import '../../ui/amount_input.dart';
import '../../ui/category_chips.dart';
import '../../ui/date_labels.dart';
import '../../ui/dialogs.dart';
import '../../ui/kit.dart';
import 'category_sheet.dart';
import 'payment_view_model.dart';

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

  Future<void> _saveAndSplit() async {
    final r = await _vm.saveAndSplit();
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

  Future<void> _pickDate(PaymentForm f) async {
    final picked = await showPastDatePicker(
      context,
      time: f.postTime,
      now: _s.now(),
    );
    if (picked != null) _vm.setDate(picked);
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopRow(
            type: f.type,
            editing: editing,
            onClose: _leave,
            onType: _vm.setType,
            onDelete: _vm.saving ? null : _delete,
          ),
          _AmountField(
            initial: f.amountText,
            autofocus: !editing,
            income: income,
            hint: editing || f.amountText.isNotEmpty
                ? '${income ? 'Received' : 'Spent'} · ${dateTimeLabel(f.postTime)}'
                : 'Type the amount.',
            onChanged: _vm.setAmount,
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  CategoryChips(
                    chips: _vm.chipCategories,
                    selectedId: f.categoryId,
                    flagNotSet: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    onPick: _vm.setCategory,
                    onMore: () => showCategorySheet(
                      context,
                      categories: _vm.categories,
                      selectedId: f.categoryId,
                      onPick: _vm.setCategory,
                    ),
                  ),
                  if (!editing && _vm.recentShops.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _RecentShops(
                      shops: _vm.recentShops,
                      selected: f.merchant.trim().toLowerCase(),
                      onPick: _vm.pickRecentShop,
                    ),
                  ],
                  const SizedBox(height: 12),
                  ListGroup(
                    children: [
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
                        singleLine: true,
                      ),
                      _TextRow(
                        label: 'Note',
                        placeholder: 'Optional',
                        icon: Icons.edit_note,
                        value: f.notes,
                        onChanged: _vm.setNotes,
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
                  if (editing && f.type == TransactionType.withdraw) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      child: TonalButton(
                        'Split this bill',
                        valid ? _saveAndSplit : null,
                        icon: Icons.groups,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
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
                    const Text('Save payment'),
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

/// Up to three chips of recent shops. A tap fills Shop and its last category.
class _RecentShops extends StatelessWidget {
  const _RecentShops({
    required this.shops,
    required this.selected,
    required this.onPick,
  });

  final List<RecentShop> shops;
  final String selected;
  final ValueChanged<RecentShop> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            'Recent shops',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in shops)
                ChoiceChip(
                  label: Text(s.name),
                  showCheckmark: false,
                  selected: s.name.toLowerCase() == selected,
                  onSelected: (_) => onPick(s),
                ),
            ],
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
    required this.singleLine,
  });

  final String label;
  final String placeholder;
  final IconData icon;
  final String value;
  final ValueChanged<String> onChanged;
  final bool singleLine;

  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  late final _controller = TextEditingController(text: widget.value);
  late final _focus = FocusNode();

  // A recent-shop chip changes the value from outside. Typing already matches it.
  @override
  void didUpdateWidget(_TextRow old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

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

/// The big amount: "RM" and a number field that opens the number keyboard.
/// A tap anywhere on it types. The text shrinks to fit, as the old amount text did.
class _AmountField extends StatefulWidget {
  const _AmountField({
    required this.initial,
    required this.autofocus,
    required this.income,
    required this.hint,
    required this.onChanged,
  });

  final String initial;
  final bool autofocus;
  final bool income;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = widget.income
        ? MoneyColors.of(context).received
        : scheme.onSurface;
    final style = tabular(theme.textTheme.displayLarge!.copyWith(color: color));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Text(widget.income ? '+ RM ' : 'RM ', style: style),
                  ),
                  IntrinsicWidth(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 48),
                      child: Semantics(
                        label: 'Amount',
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          autofocus: widget.autofocus,
                          onChanged: widget.onChanged,
                          onSubmitted: (_) => _focus.unfocus(),
                          inputFormatters: [AmountInput.formatter],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.done,
                          style: style,
                          cursorColor: scheme.primary,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: '0',
                            hintStyle: style.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              widget.hint,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
