import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/split_repository.dart' show RecentItem;
import '../../rules/amount_formatter.dart';
import '../../rules/split_math.dart';
import '../../theme/koban_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/sheets.dart';
import 'split_editor_steps.dart';
import 'split_editor_view_model.dart';
import 'split_entry.dart';

/// The quick-add sheet: one item per pass, with its people. "Add and next" keeps it open.
/// With [row] it edits that item instead. [prefill] fills the name and the unit price.
Future<void> showItemSheet(
  BuildContext context,
  SplitEditorViewModel vm, {
  ItemRow? row,
  RecentItem? prefill,
}) => showKobanSheet<void>(
  context: context,
  builder: (_) => _ItemSheet(vm: vm, row: row, prefill: prefill),
);

/// "3 × 2.70 = RM 8.10", or "RM 2.70" for one.
String lineText(KeypadEntry e) {
  final line = e.linePrice;
  if (line == null) return e.display.isEmpty ? 'RM 0.00' : e.display;
  return e.quantity > 1 ? '${e.display} = ${splitRm(line)}' : splitRm(line);
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.vm, this.row, this.prefill});

  final SplitEditorViewModel vm;
  final ItemRow? row;
  final RecentItem? prefill;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _name;
  late KeypadEntry _entry;
  late Set<String> _sharedBy;

  /// The entry that an edited row opened with, and its stored line price. While the entry
  /// is unchanged the stored price stays, so a price that qty does not divide is kept.
  KeypadEntry? _opened;
  Decimal? _openedPrice;
  int _added = 0;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    final state = widget.vm.state;
    _name = TextEditingController(
      text: row?.name ?? widget.prefill?.name ?? '',
    );
    _sharedBy =
        row?.sharedBy ?? state.items.lastOrNull?.sharedBy ?? const {meId};
    if (row == null) {
      final unit = widget.prefill?.unitPrice;
      _entry = KeypadEntry(
        unit: unit == null ? '' : AmountFormatter.formatDisplay(unit),
      );
      return;
    }
    final quantity = int.tryParse(row.quantity.trim()) ?? 1;
    final price = AmountFormatter.parseInput(row.price);
    final unit = price == null
        ? null
        : (price / Decimal.fromInt(quantity)).toDecimal(
            scaleOnInfinitePrecision: 10,
          );
    _entry = KeypadEntry(
      quantity: quantity,
      unit: unit == null ? '' : AmountFormatter.formatDisplay(unit),
    );
    _opened = _entry;
    _openedPrice = price;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _editing => widget.row != null;

  Decimal? get _price {
    final o = _opened;
    if (o != null && o.quantity == _entry.quantity && o.unit == _entry.unit) {
      return _openedPrice;
    }
    return _entry.linePrice;
  }

  bool get _valid {
    final p = _price;
    return _name.text.trim().isNotEmpty && p != null && p.sign > 0;
  }

  void _set(KeypadEntry e) => setState(() => _entry = e);

  void _press(PadKey key) {
    FocusScope.of(context).unfocus();
    _set(_entry.press(key));
  }

  void _pick(RecentItem item) {
    FocusScope.of(context).unfocus();
    setState(() {
      _name.text = item.name;
      _entry = KeypadEntry(
        quantity: _entry.quantity,
        unit: AmountFormatter.formatDisplay(item.unitPrice),
      );
    });
  }

  void _toggle(String id) => setState(
    () => _sharedBy = _sharedBy.contains(id)
        ? ({..._sharedBy}..remove(id))
        : {..._sharedBy, id},
  );

  void _save() {
    final price = _price!;
    final row = widget.row;
    if (row == null) {
      widget.vm.addItem(
        name: _name.text,
        quantity: _entry.quantity,
        price: price,
        sharedBy: _sharedBy,
      );
    } else {
      widget.vm.updateItem(
        row.key,
        (r) => r.copyWith(
          name: _name.text.trim(),
          quantity: '${_entry.quantity}',
          price: AmountFormatter.formatDisplay(price),
          sharedBy: _sharedBy,
        ),
      );
    }
  }

  void _addAndNext() {
    _save();
    setState(() {
      _added++;
      _name.clear();
      _entry = const KeypadEntry();
    });
  }

  void _done() {
    if (_valid) _save();
    Navigator.of(context).pop();
  }

  void _remove() {
    widget.vm.removeItem(widget.row!.key);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = widget.vm.state;
    final everyone = SplitEditorViewModel.everyone(state);
    final query = _name.text.trim().toLowerCase();
    final chips = [
      for (final i in widget.vm.recentItems)
        if (i.name.toLowerCase().contains(query) &&
            i.name.toLowerCase() != query)
          i,
    ].take(8).toList();
    final line = _price;
    final muted = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CardHeading(
              _editing ? 'Edit item' : 'Add item',
              trailing: _added == 0
                  ? null
                  : Text('$_added added', style: muted),
            ),
            const SizedBox(height: KobanSpace.s12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: const InputDecoration(
                labelText: 'Item',
                border: OutlineInputBorder(),
              ),
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: KobanSpace.s8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in chips)
                    ActionChip(
                      onPressed: () => _pick(i),
                      label: Text('${i.name} · ${splitRm(i.unitPrice)}'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: KobanSpace.s16),
            CardHeading(
              'Who had it',
              trailing: Text(
                _sharedBy.isEmpty
                    ? 'Pick someone'
                    : line == null
                    ? 'Shared by ${_sharedBy.length}'
                    : 'Shared by ${_sharedBy.length}, ${splitRm(eachOf(line, _sharedBy.length))} each',
                style: muted,
              ),
            ),
            const SizedBox(height: KobanSpace.s8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (state.people.isNotEmpty)
                  PersonChip(
                    'Everyone',
                    avatar: false,
                    selected: _sharedBy.length == everyone.length,
                    onTap: () => setState(
                      () => _sharedBy = _sharedBy.length == everyone.length
                          ? <String>{}
                          : everyone,
                    ),
                  ),
                PersonChip(
                  'Me',
                  selected: _sharedBy.contains(meId),
                  onTap: () => _toggle(meId),
                ),
                for (final p in state.people)
                  PersonChip(
                    p.name,
                    selected: _sharedBy.contains(p.id),
                    onTap: () => _toggle(p.id),
                  ),
              ],
            ),
            const SizedBox(height: KobanSpace.s16),
            Row(
              children: [
                Text('Qty', style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'One less',
                  onPressed: _entry.quantity > 1
                      ? () => _set(_entry.withQuantity(_entry.quantity - 1))
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '${_entry.quantity}',
                  style: tabular(theme.textTheme.titleLarge!),
                ),
                IconButton(
                  tooltip: 'One more',
                  onPressed: _entry.quantity < KeypadEntry.maxQuantity
                      ? () => _set(_entry.withQuantity(_entry.quantity + 1))
                      : null,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      lineText(_entry),
                      textAlign: TextAlign.end,
                      style: tabular(theme.textTheme.titleLarge!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KobanSpace.s8),
            _Keypad(onKey: _press),
            const SizedBox(height: KobanSpace.s16),
            Row(
              children: [
                Expanded(
                  child: _editing
                      ? TextButton(
                          onPressed: _remove,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            foregroundColor: scheme.error,
                          ),
                          child: const Text('Remove'),
                        )
                      : OutlinedButton(
                          onPressed: _done,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text('Done'),
                        ),
                ),
                const SizedBox(width: KobanSpace.s12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _valid ? (_editing ? _done : _addAndNext) : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: Text(_editing ? 'Save' : 'Add and next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Digits, '.', '00', Delete and Times. Times takes the typed number as the quantity.
class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<PadKey> onKey;

  static const _rows = [
    [PadKey.d1, PadKey.d2, PadKey.d3],
    [PadKey.d4, PadKey.d5, PadKey.d6],
    [PadKey.d7, PadKey.d8, PadKey.d9],
    [PadKey.dot, PadKey.d0, PadKey.d00],
  ];
  static const _height = 52.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget key(PadKey k, {double height = _height}) {
      final icon = switch (k) {
        PadKey.back => Icons.backspace_outlined,
        PadKey.times => Icons.close,
        _ => null,
      };
      final side = icon != null;
      return SizedBox(
        key: ValueKey(k),
        height: height,
        child: Material(
          color: side ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(KobanRadius.r16),
          child: Semantics(
            button: true,
            label: k.label,
            onTap: () => onKey(k),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(KobanRadius.r16),
              onTap: () => onKey(k),
              child: Center(
                child: icon == null
                    ? Text(k.label, style: tabular(theme.textTheme.titleLarge!))
                    : Icon(icon, color: scheme.onPrimaryContainer),
              ),
            ),
          ),
        ),
      );
    }

    const tall = _height * 2 + _gap;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (final (i, row) in _rows.indexed) ...[
                if (i > 0) const SizedBox(height: _gap),
                Row(
                  children: [
                    for (final (j, k) in row.indexed) ...[
                      if (j > 0) const SizedBox(width: _gap),
                      Expanded(child: key(k)),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: 76,
          child: Column(
            children: [
              key(PadKey.back, height: tall),
              const SizedBox(height: _gap),
              key(PadKey.times, height: tall),
            ],
          ),
        ),
      ],
    );
  }
}
