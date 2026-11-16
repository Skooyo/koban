import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../receipts/receipt_photos.dart';
import '../../rules/amount_formatter.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
import '../../ui/amount_input.dart';
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
/// A port of `SplitEditorScreen.kt`.
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
        // The step bar shows the reading step as the photo step.
        final barStep = state.step == SplitStep.reading
            ? 0
            : state.step.index - (state.step.index > 1 ? 1 : 0);
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
                        number: barStep + 1,
                        total: _stepNames.length,
                        name: _stepNames[barStep],
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
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
                            if (action.hint != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  action.hint!,
                                  style: theme.textTheme.bodySmall!.copyWith(
                                    color: MoneyColors.of(context).review,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
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
      SplitStep.photo => _PhotoStep(state: state, vm: vm),
      SplitStep.reading => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Reading the receipt…',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
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

typedef _BottomAction = ({
  String label,
  bool enabled,
  VoidCallback onPressed,
  String? hint,
});

_BottomAction? _bottomAction(SplitEditorState s, SplitEditorViewModel vm) {
  if (s.loading) return null;
  return switch (s.step) {
    SplitStep.photo || SplitStep.reading => null,
    SplitStep.items => (
      label: 'Next',
      enabled:
          s.items.isNotEmpty &&
          SplitEditorViewModel.parseItems(s) != null &&
          SplitEditorViewModel.chargesOf(s) != null,
      onPressed: vm.next,
      hint: null,
    ),
    SplitStep.people => (
      label:
          'Next · ${s.people.length + 1} ${s.people.isEmpty ? 'person' : 'people'}',
      enabled: true,
      onPressed: vm.next,
      hint: null,
    ),
    SplitStep.assign => (
      label: 'Next',
      enabled: SplitEditorViewModel.unassigned(s).isEmpty,
      onPressed: vm.next,
      hint: switch (SplitEditorViewModel.unassigned(s).length) {
        0 => null,
        1 => '1 item has no one yet. Pick someone to go on.',
        final n => '$n items have no one yet. Pick someone to go on.',
      },
    ),
    SplitStep.link =>
      s.locked
          ? (
              label: 'Save payment',
              enabled: true,
              onPressed: vm.saveLockedPayment,
              hint: null,
            )
          : (label: 'Next', enabled: true, onPressed: vm.next, hint: null),
    SplitStep.summary =>
      s.locked
          ? null
          : (
              label: 'Done',
              enabled:
                  s.amounts == null ||
                  SplitEditorViewModel.amountsLeft(s)?.sign == 0,
              onPressed: vm.done,
              hint: null,
            ),
  };
}

class _PhotoStep extends StatefulWidget {
  const _PhotoStep({required this.state, required this.vm});

  final SplitEditorState state;
  final SplitEditorViewModel vm;

  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  bool _picking = false;

  /// Opens a photo source and reads the photo it gives. A cancel gives null and changes nothing.
  /// As in 0.1.1, a failed photo shows nothing: the editor stays on the receipt step.
  Future<void> _pick(Future<String?> Function() source) async {
    if (_picking) return;
    // Read before the await: a closed editor has no context.
    final cacheDir = AppScope.of(context).cacheDir;
    setState(() => _picking = true);
    String? path;
    try {
      path = await source();
    } catch (e) {
      developer.log(
        'Photo source failed: ${e.runtimeType}',
        name: 'SplitEditorScreen',
      );
    }
    if (!mounted) {
      // The editor closed: nobody reads this photo. Delete it when it is in the cache.
      if (path != null) unawaited(_deleteCached(path, cacheDir));
      return;
    }
    setState(() => _picking = false);
    if (path != null) unawaited(widget.vm.readReceipt(path));
  }

  Future<void> _deleteCached(
    String path,
    Future<Directory> Function() cacheDir,
  ) async {
    try {
      await deleteIfCache(path, (await cacheDir()).path);
    } catch (e) {
      developer.log(
        'Photo delete failed: ${e.runtimeType}',
        name: 'SplitEditorScreen',
      );
    }
  }

  /// One amount, shared by everyone. A split of a payment uses its amount and shop.
  Future<void> _splitWithoutReceipt() async {
    final payment = widget.state.linkedPayment;
    if (payment != null) {
      final shop = payment.merchant?.trim() ?? '';
      return widget.vm.splitWithoutReceipt(
        payment.amount,
        shop.isEmpty ? _sharedCost : shop,
      );
    }
    final picked = await showDialog<(Decimal, String)>(
      context: context,
      builder: (_) => const _OneAmountDialog(),
    );
    if (picked != null && mounted) {
      widget.vm.splitWithoutReceipt(picked.$1, picked.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payment = widget.state.linkedPayment;
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
                      widget.state.onlineAccess
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
              onPressed: _picking
                  ? null
                  : () => _pick(AppScope.of(context).receiptPhotos.scan),
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Take photo'),
            ),
          ),
          const SizedBox(height: 8),
          _WideButton(
            OutlinedButton.icon(
              onPressed: _picking
                  ? null
                  : () => _pick(AppScope.of(context).pickImage),
              icon: const Icon(Icons.image, size: 18),
              label: const Text('Choose from gallery'),
            ),
          ),
          const SizedBox(height: 8),
          _WideButton(
            TonalButton(
              payment == null
                  ? 'Split one amount, no receipt'
                  : 'Split ${splitRm(payment.amount)} evenly, no receipt',
              _picking ? null : _splitWithoutReceipt,
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

const _sharedCost = 'Shared cost';

/// Asks for the amount and the name of a split with no receipt and no payment.
class _OneAmountDialog extends StatefulWidget {
  const _OneAmountDialog();

  @override
  State<_OneAmountDialog> createState() => _OneAmountDialogState();
}

class _OneAmountDialogState extends State<_OneAmountDialog> {
  final _amount = TextEditingController();
  final _name = TextEditingController(text: _sharedCost);

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    final amount = AmountInput.toAmount(_amount.text);
    if (amount == null) return;
    final name = _name.text.trim();
    Navigator.pop(context, (amount, name.isEmpty ? _sharedCost : name));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: scheme.surfaceContainer,
      title: const Text('Split one amount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            autofocus: true,
            inputFormatters: [AmountInput.formatter],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount (RM)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _next(),
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder(
          valueListenable: _amount,
          builder: (context, value, _) => TextButton(
            onPressed: AmountInput.toAmount(value.text) == null ? null : _next,
            child: const Text('Next'),
          ),
        ),
      ],
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

/// The Fix sheet of 0.1.1. It closes when no mismatch is left and Claude does not read.
Future<void> showFixSheet(BuildContext context, SplitEditorViewModel vm) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _FixSheet(vm: vm),
    );

class _FixSheet extends StatefulWidget {
  const _FixSheet({required this.vm});

  final SplitEditorViewModel vm;

  @override
  State<_FixSheet> createState() => _FixSheetState();
}

class _FixSheetState extends State<_FixSheet> {
  bool _closing = false;

  /// Closes the sheet once, for a button or for a read that removed the gap.
  /// A second pop would remove the editor.
  void _close({bool later = false}) {
    if (_closing) return;
    _closing = true;
    // A sheet that already leaves is not the current route: a pop would remove the editor.
    void pop() {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    }

    if (later) {
      WidgetsBinding.instance.addPostFrameCallback((_) => pop());
    } else {
      pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final vm = widget.vm;
        final state = vm.state;
        final diff = SplitEditorViewModel.difference(state);
        if (state.readingAgain) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reading with Claude… about 10 seconds',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (diff == null) {
          _close(later: true);
          return const SizedBox.shrink();
        }
        final readsLeft = state.readsLeft;
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
                    _close();
                    vm.addRoundingDifference();
                  },
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: Text(
                    'Add RM ${AmountFormatter.formatDisplay(diff)} as rounding',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _close,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Edit by hand'),
                ),
                if (state.canReadAgain) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: vm.readAgainWithClaude,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: Column(
                      children: [
                        const Text('Read again with Claude'),
                        Text(
                          "Sends the photo to Koban's server${readsLeft == null ? '' : ' · $readsLeft reads left today'}",
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

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
        if (state.readSource != null ||
            diff != null ||
            message != null ||
            (state.readNote != null && diff == null)) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.readSource != null) ...[
                Row(
                  children: [
                    Icon(Icons.check, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.readSource!,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (diff != null) ...[
                MismatchCard(
                  diff: diff,
                  total: total,
                  printed: printed,
                  onFix: () => showFixSheet(context, vm),
                ),
                const SizedBox(height: 12),
              ],
              if (message != null) ...[
                Text(
                  message,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (state.readNote != null && diff == null)
                Text(
                  state.readNote!,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          gap,
        ],
        SplitField(
          label: 'Shop',
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
                child: SplitField(
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
                child: SplitField(
                  label: 'Qty',
                  value: row.quantity,
                  keyboard: TextInputType.number,
                  onChanged: (v) =>
                      vm.updateItem(row.key, (r) => r.copyWith(quantity: v)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SplitField(
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
    child: SplitField(
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
