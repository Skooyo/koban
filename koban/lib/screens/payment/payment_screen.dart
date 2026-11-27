import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../rules/types.dart';
import '../../theme/koban_theme.dart';
import '../../ui/amount_input.dart';
import '../../ui/category_chips.dart';
import '../../ui/date_labels.dart';
import '../../ui/dialogs.dart';
import '../../ui/kit.dart';
import '../../ui/scene_band.dart';
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
        if (f == null) return _loadFailedPage(context);
        return PopScope(
          canPop: !_vm.hasChanges || _vm.saving,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _leave();
          },
          child: Scaffold(
            body: SafeArea(top: false, child: _content(context, f)),
          ),
        );
      },
    );
  }

  /// Empty while an edited payment loads. A failed load shows its text and a Close button.
  Widget _loadFailedPage(BuildContext context) {
    final error = _vm.loadError;
    if (error == null) return const Scaffold();
    return Scaffold(
      body: Column(
        children: [
          const TaskHeader(title: 'Payment'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
            child: WarningRow(error),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, PaymentForm f) {
    final income = f.type == TransactionType.receive;
    final editing = _vm.isEditing;
    final valid = AmountInput.toAmount(f.amountText) != null;
    final splitting = _vm.splitWithFriends && !income;
    final pastCount = _vm.pastCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaskHeader(
                  title: editing ? 'Payment' : 'Add payment',
                  action: editing
                      ? SceneIconButton(
                          icon: Icons.delete,
                          tooltip: 'Delete payment',
                          onPressed: _vm.saving ? null : _delete,
                        )
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      DirectionSegments(selected: f.type, onPick: _vm.setType),
                      _AmountField(
                        initial: f.amountText,
                        autofocus: !editing,
                        income: income,
                        onChanged: _vm.setAmount,
                      ),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _pickDate(f),
                          icon: const Icon(Icons.calendar_month),
                          label: Text(dateTimeLabel(f.postTime)),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                      ),
                      if (_vm.loadError case final error?) WarningRow(error),
                      if (!editing && _vm.recentShops.isNotEmpty)
                        _RecentShops(
                          shops: _vm.recentShops,
                          selected: f.merchant.trim().toLowerCase(),
                          onPick: _vm.pickRecentShop,
                        ),
                      CategoryChips(
                        chips: _vm.chipCategories,
                        selectedId: f.categoryId,
                        flagNotSet: false,
                        padding: EdgeInsets.zero,
                        onPick: _vm.setCategory,
                        onMore: () => showCategorySheet(
                          context,
                          categories: _vm.categories,
                          selectedId: f.categoryId,
                          onPick: _vm.setCategory,
                        ),
                      ),
                      _LabeledField(
                        label: 'Shop',
                        value: f.merchant,
                        onChanged: _vm.setMerchant,
                        singleLine: true,
                      ),
                      if (pastCount > 0)
                        CheckboxListTile(
                          value: _vm.changePast,
                          onChanged: (v) => _vm.setChangePast(v ?? false),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            'Also change $pastCount past ${f.merchant.trim()} '
                            '${pastCount == 1 ? 'payment' : 'payments'} '
                            'to ${_categoryName(f.categoryId)}',
                          ),
                        ),
                      _LabeledField(
                        label: 'Note (optional)',
                        value: f.notes,
                        onChanged: _vm.setNotes,
                        singleLine: false,
                      ),
                      if (_vm.inGroups && !income)
                        ListGroup(
                          children: [
                            MergeSemantics(
                              child: Semantics(
                                toggled: !f.privateToGroups,
                                child: KobanRow(
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
                                  onTap: () => _vm.setPrivateToGroups(
                                    !f.privateToGroups,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (!editing && !income)
                        ListGroup(
                          children: [
                            MergeSemantics(
                              child: Semantics(
                                toggled: splitting,
                                child: KobanRow(
                                  title: 'Split with friends',
                                  subtitle: 'Pick people after you save',
                                  trailing: ExcludeSemantics(
                                    child: IgnorePointer(
                                      child: Switch(
                                        value: splitting,
                                        onChanged: (_) {},
                                      ),
                                    ),
                                  ),
                                  onTap: () => _vm.setSplitWithFriends(
                                    !_vm.splitWithFriends,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (editing && !income)
                        SizedBox(
                          height: 56,
                          child: TonalButton(
                            'Split this bill',
                            valid ? _saveAndSplit : null,
                            icon: Icons.groups,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: FilledButton(
              onPressed: valid ? _save : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(splitting ? Icons.groups : Icons.check, size: 18),
                  const SizedBox(width: 8),
                  Text(splitting ? 'Save and split' : 'Save payment'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _categoryName(String? id) {
    for (final c in _vm.categories) {
      if (c.id == id) return c.name;
    }
    return 'this category';
  }
}

/// Up to four chips of recent shops. A tap fills Shop and its last category.
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

/// A text field with its label on top. Shop and Note.
class _LabeledField extends StatefulWidget {
  const _LabeledField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.singleLine,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool singleLine;

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  late final _controller = TextEditingController(text: widget.value);

  // A recent-shop chip changes the value from outside. Typing already matches it.
  @override
  void didUpdateWidget(_LabeledField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const shape = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    );
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      style: theme.textTheme.titleMedium!.copyWith(color: scheme.onSurface),
      cursorColor: scheme.primary,
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
        labelText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: theme.textTheme.bodyMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: shape,
        enabledBorder: shape,
        focusedBorder: shape,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        constraints: const BoxConstraints(minHeight: 48),
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
    required this.onChanged,
  });

  final String initial;
  final bool autofocus;
  final bool income;
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
      excludeFromSemantics: true,
      onTap: _focus.requestFocus,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
          ],
        ),
      ),
    );
  }
}
