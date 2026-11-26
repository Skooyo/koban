import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../rules/amount_formatter.dart';
import '../../theme/koban_theme.dart';
import '../../ui/kit.dart';
import '../../ui/undo_snack_bar.dart';
import 'settings_view_model.dart';
import 'settings_widgets.dart';

/// Categories and budgets: one row per category with its monthly limit, and the new category field.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.vm});

  final SettingsViewModel vm;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _name = TextEditingController();
  String? _nameError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final same = widget.vm.categoryNamed(name);
    if (same != null) {
      setState(() => _nameError = 'You have a category called ${same.name}');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    await widget.vm.addCategory(name);
    if (!mounted) return;
    setState(() {
      _name.clear();
      _nameError = null;
    });
    showUndoSnackBar(messenger, '$name added');
  }

  Future<void> _delete(String id, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await widget.vm.deleteCategory(id);
    if (result == null) return;
    final n = result.payments;
    showUndoSnackBar(messenger, switch (n) {
      0 => '$name deleted.',
      1 => '$name deleted. 1 payment is now Uncategorized.',
      _ => '$name deleted. $n payments are now Uncategorized.',
    }, undo: result.undo);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => SettingsPage(
        title: 'Categories and budgets',
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'A monthly limit counts this month’s Spent payments in RM. Empty means no limit.',
              style: text.bodyMedium!.copyWith(color: muted),
            ),
          ),
          if (vm.categories.isNotEmpty)
            ListGroup(
              children: [
                for (final c in vm.categories)
                  KobanRow(
                    key: ValueKey(c.id),
                    title: c.name,
                    subtitle: c.isDefault ? null : 'Your own',
                    leading: CategoryDot(categoryColor(context, c.id)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 144,
                          child: _LimitField(
                            key: ValueKey('limit-${c.id}'),
                            name: c.name,
                            limit: vm.limits[c.id],
                            onSave: (v) => vm.saveLimit(c.id, v),
                          ),
                        ),
                        if (!c.isDefault)
                          IconButton(
                            onPressed: () => _delete(c.id, c.name),
                            tooltip: 'Delete category ${c.name}',
                            icon: const Icon(Icons.delete),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Received payments and Uncategorized have no limit.',
              style: text.bodySmall!.copyWith(color: muted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    onChanged: (_) => setState(() => _nameError = null),
                    onSubmitted: (_) => _add(),
                    textInputAction: TextInputAction.done,
                    maxLines: 1,
                    decoration: InputDecoration(
                      labelText: 'New category',
                      errorText: _nameError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TonalButton('Add', _name.text.trim().isEmpty ? null : _add),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Categories and notes are saved on this phone only.',
              style: text.bodySmall!.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Monthly limit" field of one category. It saves when it loses focus or the screen closes.
/// Empty clears the limit. Anything that is not above 0 puts the old limit back.
class _LimitField extends StatefulWidget {
  const _LimitField({
    super.key,
    required this.name,
    required this.limit,
    required this.onSave,
  });

  final String name;
  final Decimal? limit;
  final void Function(Decimal? amount) onSave;

  @override
  State<_LimitField> createState() => _LimitFieldState();
}

class _LimitFieldState extends State<_LimitField> {
  late final TextEditingController _text = TextEditingController(
    text: _show(widget.limit),
  );
  final _focus = FocusNode();

  static String _show(Decimal? v) =>
      v == null ? '' : AmountFormatter.formatDisplay(v);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_LimitField old) {
    super.didUpdateWidget(old);
    // An outside change, such as Undo, shows at once unless the friend is typing.
    if (old.limit != widget.limit && !_focus.hasFocus) {
      _text.text = _show(widget.limit);
    }
  }

  @override
  void dispose() {
    if (_focus.hasFocus) _commit();
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _commit() {
    final raw = _text.text.trim();
    if (raw.isEmpty) {
      if (widget.limit != null) widget.onSave(null);
      return;
    }
    final value = AmountFormatter.parseInput(raw);
    if (value == null || value <= Decimal.zero) {
      _text.text = _show(widget.limit);
      return;
    }
    _text.text = _show(value);
    if (value != widget.limit) widget.onSave(value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${widget.name} monthly limit',
    child: TextField(
      controller: _text,
      focusNode: _focus,
      textAlign: TextAlign.end,
      textInputAction: TextInputAction.done,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      onTapOutside: (_) => _focus.unfocus(),
      decoration: const InputDecoration(
        prefixText: 'RM ',
        hintText: 'None',
        border: OutlineInputBorder(),
      ),
    ),
  );
}
