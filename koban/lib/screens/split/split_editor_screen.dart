import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/online_placeholder.dart';
import '../../rules/amount_formatter.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
import '../../ui/dialogs.dart';
import '../../ui/kit.dart';
import 'split_editor_steps.dart';
import 'split_editor_view_model.dart';

const _stepNames = [
  'Receipt',
  'Items',
  'People',
  'Who had what',
  'Payment',
  'Summary',
];

/// The split editor: a new split, a split of a payment, or a saved split.
/// A port of `SplitEditorScreen.kt` without the receipt reading.
class SplitEditorScreen extends StatefulWidget {
  const SplitEditorScreen({super.key, this.billId, this.expenseId});

  final String? billId;
  final String? expenseId;

  @override
  State<SplitEditorScreen> createState() => SplitEditorScreenState();
}

class SplitEditorScreenState extends State<SplitEditorScreen> {
  SplitEditorViewModel? _vm;
  bool _closing = false;
  bool _asking = false;

  /// The view-model of the screen. Tests read its state.
  @visibleForTesting
  SplitEditorViewModel get viewModel => _vm!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm ??= SplitEditorViewModel(
      AppScope.of(context),
      billId: widget.billId,
      expenseId: widget.expenseId,
    )..addListener(_closeIfFinished);
  }

  @override
  void dispose() {
    _vm
      ?..removeListener(_closeIfFinished)
      ..dispose();
    super.dispose();
  }

  void _closeIfFinished() {
    if (_vm!.state.finished) _close();
  }

  void _close() {
    if (_closing || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _closing = true;
    Navigator.of(context).pop();
  }

  Future<void> _goBack() async {
    final vm = _vm!;
    if (!vm.back()) return _close();
    if (!vm.state.confirmDiscard || _asking) return;
    _asking = true;
    final discard = await showDiscardChangesDialog(context);
    _asking = false;
    if (discard) {
      vm.discardEdits();
      _close();
    } else {
      vm.keepEditing();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final state = vm.state;
        final action = _bottomAction(state, vm);
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _goBack();
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _goBack,
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Semantics(
                              header: true,
                              child: Text(
                                'Split a bill',
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!state.loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: StepProgress(
                        number: state.step.index + 1,
                        total: _stepNames.length,
                        name: _stepNames[state.step.index],
                      ),
                    ),
                  Expanded(child: _content(state, vm)),
                  if (action != null)
                    Material(
                      color: theme.colorScheme.surfaceContainer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: action.enabled && !state.saving
                                ? action.onPressed
                                : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            child: Text(action.label),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _content(SplitEditorState state, SplitEditorViewModel vm) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final loadError = state.error;
    if (state.step == SplitStep.photo && loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            loadError,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge!
                .copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    return switch (state.step) {
      SplitStep.photo => _PhotoStep(online: state.onlineAccess, vm: vm),
      SplitStep.items => _ItemsStep(state: state, vm: vm),
      SplitStep.people => PeopleStep(state: state, vm: vm),
      SplitStep.assign => AssignStep(state: state, vm: vm),
      SplitStep.link => LinkStep(state: state, vm: vm),
      SplitStep.summary => SummaryStep(state: state, vm: vm, onShare: _share),
    };
  }

  Future<void> _share(String text) async {
    try {
      await AppScope.of(context).device.shareText(text);
    } catch (e, s) {
      developer.log(
        'Share summary failed',
        name: 'SplitEditorScreen',
        error: e,
        stackTrace: s,
      );
    }
  }
}

typedef _BottomAction = ({String label, bool enabled, VoidCallback onPressed});

_BottomAction? _bottomAction(SplitEditorState s, SplitEditorViewModel vm) {
  if (s.loading) return null;
  return switch (s.step) {
    SplitStep.photo => null,
    SplitStep.items => (
      label: 'Next',
      enabled:
          s.items.isNotEmpty &&
          SplitEditorViewModel.parseItems(s) != null &&
          SplitEditorViewModel.chargesOf(s) != null,
      onPressed: vm.next,
    ),
    SplitStep.people => (
      label:
          'Next · ${s.people.length + 1} ${s.people.isEmpty ? 'person' : 'people'}',
      enabled: true,
      onPressed: vm.next,
    ),
    SplitStep.assign => (
      label: 'Next',
      enabled: SplitEditorViewModel.unassigned(s).isEmpty,
      onPressed: vm.next,
    ),
    SplitStep.link =>
      s.locked
          ? (
              label: 'Save payment',
              enabled: true,
              onPressed: vm.saveLockedPayment,
            )
          : (label: 'Next', enabled: true, onPressed: vm.next),
    SplitStep.summary =>
      s.locked ? null : (label: 'Done', enabled: true, onPressed: vm.done),
  };
}

class _PhotoStep extends StatefulWidget {
  const _PhotoStep({required this.online, required this.vm});

  final bool online;
  final SplitEditorViewModel vm;

  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  bool _opening = false;

  /// Receipt reading comes in milestone 5. Both photo buttons open its placeholder.
  Future<void> _openReading() async {
    if (_opening) return;
    _opening = true;
    await openOnlinePlaceholder(context, OnlineFeature.receiptReading);
    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Mon(MonFace.idle, size: 96),
                  const SizedBox(height: 16),
                  Text(
                    'Start with the receipt',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.online
                          ? "Koban reads the items for you. With online access, the photo goes to Koban's server to be read, then it is deleted."
                          : 'Koban reads the items for you. The photo is read once and then deleted. It is not kept.',
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _WideButton(
            FilledButton.icon(
              onPressed: _openReading,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Take photo'),
            ),
          ),
          const SizedBox(height: 8),
          _WideButton(
            OutlinedButton.icon(
              onPressed: _openReading,
              icon: const Icon(Icons.image, size: 18),
              label: const Text('Choose from gallery'),
            ),
          ),
          const SizedBox(height: 8),
          _WideButton(
            TextButton(
              onPressed: widget.vm.typeItemsInstead,
              child: const Text('Type items instead'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48, minWidth: double.infinity),
    child: child,
  );
}

/// Items and the receipt total differ: a card with the `review` outline and a Fix button.
class MismatchCard extends StatelessWidget {
  const MismatchCard({
    super.key,
    required this.diff,
    required this.total,
    required this.printed,
    required this.onFix,
  });

  final Decimal diff;
  final Decimal? total;
  final Decimal? printed;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final review = MoneyColors.of(context).review;
    final total = this.total;
    final printed = this.printed;
    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: review),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: review, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Differs from the receipt total by RM ${AmountFormatter.formatDisplay(diff.abs())}.',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (total != null && printed != null) ...[
              const SizedBox(height: 8),
              Text(
                'Items add up to ${splitRm(total)}. The receipt says ${splitRm(printed)}.',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TonalButton('Fix', onFix),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Fix sheet of 0.1.1 without "Read again with Claude".
Future<void> showFixSheet(
  BuildContext context,
  Decimal diff,
  SplitEditorViewModel vm,
) => showModalBottomSheet<void>(
  context: context,
  builder: (context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Differs from the receipt total by RM ${AmountFormatter.formatDisplay(diff.abs())}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                vm.addRoundingDifference();
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(
                'Add RM ${AmountFormatter.formatDisplay(diff)} as rounding',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Edit by hand'),
            ),
          ],
        ),
      ),
    );
  },
);

class _ItemsStep extends StatelessWidget {
  const _ItemsStep({required this.state, required this.vm});

  final SplitEditorState state;
  final SplitEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = SplitEditorViewModel.totalOf(state);
    final diff = SplitEditorViewModel.difference(state);
    final printed = state.printedTotal;
    final message = state.message;
    const gap = SizedBox(height: 16);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (diff != null) ...[
          MismatchCard(
            diff: diff,
            total: total,
            printed: printed,
            onFix: () => showFixSheet(context, diff, vm),
          ),
          gap,
        ],
        if (message != null) ...[
          Text(
            message,
            style: theme.textTheme.bodyMedium!.copyWith(color: scheme.error),
          ),
          gap,
        ],
        _Field(
          label: 'Place',
          value: state.merchant,
          onChanged: vm.setMerchant,
        ),
        gap,
        const SectionHeading('Items'),
        if (state.items.isNotEmpty)
          ListGroup(
            children: [
              for (final row in state.items)
                _ItemEditor(key: ValueKey(row.key), row: row, vm: vm),
            ],
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: TextButton.icon(
            onPressed: vm.addItem,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add item'),
          ),
        ),
        gap,
        const SectionHeading('Charges'),
        ListGroup(
          children: [
            _MoneyField(
              'Service charge',
              state.serviceCharge,
              vm.setServiceCharge,
            ),
            _MoneyField('SST', state.tax, vm.setTax),
            _MoneyField('Discount', state.discount, vm.setDiscount),
            _MoneyField(
              'Rounding',
              state.rounding,
              vm.setRounding,
              keyboard: TextInputType.text,
              hint: 'Use - for a negative amount',
            ),
          ],
        ),
        gap,
        ListGroup(
          children: [
            KobanRow(
              title: 'Total',
              trailing: total != null
                  ? MoneyText(splitRm(total), style: theme.textTheme.titleLarge)
                  : Text(
                      'Check the amounts',
                      style: theme.textTheme.bodyLarge!.copyWith(
                        color: scheme.error,
                      ),
                    ),
            ),
            if (printed != null)
              KobanRow(
                title: 'Receipt total',
                trailing: MoneyText(
                  splitRm(printed),
                  style: theme.textTheme.bodyLarge,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ItemEditor extends StatelessWidget {
  const _ItemEditor({super.key, required this.row, required this.vm});

  final ItemRow row;
  final SplitEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final price = AmountFormatter.parseInput(row.price);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: 'Item',
                  value: row.name,
                  onChanged: (v) =>
                      vm.updateItem(row.key, (r) => r.copyWith(name: v)),
                ),
              ),
              IconButton(
                onPressed: () => vm.removeItem(row.key),
                tooltip:
                    'Remove ${row.name.trim().isEmpty ? 'item' : row.name}',
                icon: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: _Field(
                  label: 'Qty',
                  value: row.quantity,
                  keyboard: TextInputType.number,
                  onChanged: (v) =>
                      vm.updateItem(row.key, (r) => r.copyWith(quantity: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  label: 'Line price (RM)',
                  value: row.price,
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  isError:
                      row.price.trim().isNotEmpty && (price?.sign ?? 0) <= 0,
                  onChanged: (v) =>
                      vm.updateItem(row.key, (r) => r.copyWith(price: v)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField(
    this.label,
    this.value,
    this.onChanged, {
    this.keyboard = const TextInputType.numberWithOptions(decimal: true),
    this.hint,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType keyboard;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: _Field(
      label: '$label (RM)',
      value: value,
      onChanged: onChanged,
      keyboard: keyboard,
      hint: hint,
      isError:
          value.trim().isNotEmpty && AmountFormatter.parseInput(value) == null,
    ),
  );
}

/// An outlined one-line text field. It shows [value] again when the state changes it.
class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.onChanged,
    this.keyboard,
    this.hint,
    this.isError = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboard;
  final String? hint;
  final bool isError;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_Field old) {
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
    decoration: InputDecoration(
      labelText: widget.label,
      border: const OutlineInputBorder(),
      helperText: widget.isError ? null : widget.hint,
      errorText: widget.isError ? (widget.hint ?? '') : null,
    ),
  );
}
