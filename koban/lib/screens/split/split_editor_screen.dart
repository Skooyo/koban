import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../data/split_repository.dart' show RecentItem;
import '../../receipts/receipt_photos.dart';
import '../../rules/amount_formatter.dart';
import '../../rules/split_math.dart';
import '../../theme/koban_theme.dart';
import '../../theme/tokens.dart';
import '../../ui/amount_input.dart';
import '../../ui/dialogs.dart';
import '../../ui/kit.dart';
import '../../ui/scene_band.dart';
import '../../ui/sheets.dart';
import 'split_editor_steps.dart';
import 'split_editor_view_model.dart';
import 'split_entry.dart';
import 'split_item_sheet.dart';

/// The split editor: a new split, a split of a payment, or a saved split.
/// A port of `SplitEditorScreen.kt`, in the Mon's desk look.
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

  /// Goes to the items and opens the quick-add sheet, filled with [prefill] when given.
  void _typeItems([RecentItem? prefill]) {
    final vm = _vm!;
    vm.typeItemsInstead();
    showItemSheet(context, vm, prefill: prefill);
  }

  Future<void> _share() async {
    final text = SplitEditorViewModel.shareText(_vm!.state);
    if (text == null) return;
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

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final state = vm.state;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _goBack();
          },
          child: Scaffold(
            body: Column(
              children: [
                _band(context, state),
                _stepLine(context, state),
                Expanded(child: _content(state, vm)),
                ?_bottomBar(context, state, vm),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _band(BuildContext context, SplitEditorState s) {
    final shop = SplitEditorViewModel.shopOf(s);
    final (title, number) = switch (s.step) {
      _ when s.loading => ('Split a bill', null),
      SplitStep.people => ('Split a bill', 1),
      SplitStep.start || SplitStep.reading => (shop ?? 'Split a bill', 2),
      SplitStep.items => (shop ?? 'Items', 2),
      SplitStep.link => ('Payment', 3),
      SplitStep.summary => ('Split done', 3),
    };
    return TaskHeader(
      title: title,
      action: number == null || s.billId != null ? null : _StepPill(number),
    );
  }

  Widget _stepLine(BuildContext context, SplitEditorState s) {
    final (line, detail) = _stepSays(s);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line, style: theme.textTheme.titleMedium),
          if (detail != null)
            Text(
              detail,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  /// The plain line and detail for the step, shown under the header.
  (String, String?) _stepSays(SplitEditorState s) {
    if (s.loading) return ('Opening the bill.', null);
    switch (s.step) {
      case SplitStep.people:
        if (s.error != null) return ('That did not open.', null);
        return ('Who ate with you?', 'Tap names. No typing.');
      case SplitStep.start:
        return ('Got the receipt?', 'I can read it for you.');
      case SplitStep.reading:
        return ('Reading every line.', 'This takes a few seconds.');
      case SplitStep.items:
        final missing = SplitEditorViewModel.unassigned(s).length;
        final rest = SplitEditorViewModel.missingItemsOf(s);
        if (s.items.isEmpty) {
          return ('What did you have?', 'Add the items. I do the sums.');
        }
        if (rest != null && rest.sign > 0) {
          return (
            '${splitRm(rest)} is on no one yet.',
            'Shared food? Split it evenly.',
          );
        }
        if (missing > 0) {
          return (
            missing == 1 ? '1 item has no one.' : '$missing items have no one.',
            'Tap the faces on each item.',
          );
        }
        if (SplitEditorViewModel.difference(s) != null) {
          return ('This does not match the receipt.', 'Fix it below.');
        }
        return ('Every item has someone.', 'Check the charges, then Next.');
      case SplitStep.link:
        return (
          'Which payment was this?',
          'Link the card payment, so your spending counts only your share.',
        );
      case SplitStep.summary:
        final owing = owingNames(s);
        return (
          'Every sen is on someone.',
          s.locked
              ? "Someone has paid you back, so the items can't change."
              : owing.isEmpty
              ? null
              : '${joinNames(owing)} now ${owing.length == 1 ? 'owes' : 'owe'} you.',
        );
    }
  }

  Widget _content(SplitEditorState state, SplitEditorViewModel vm) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final loadError = state.error;
    if (state.step == SplitStep.people && loadError != null) {
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
      SplitStep.people => PeopleStep(state: state, vm: vm),
      SplitStep.start => _StartStep(
        state: state,
        vm: vm,
        onTypeItems: _typeItems,
      ),
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
      SplitStep.link => LinkStep(state: state, vm: vm),
      SplitStep.summary => SummaryStep(state: state, vm: vm),
    };
  }

  Widget? _bottomBar(
    BuildContext context,
    SplitEditorState s,
    SplitEditorViewModel vm,
  ) {
    if (s.loading) return null;
    final theme = Theme.of(context);
    String? caption;
    String? value;
    String? hint;
    Widget? second;
    final ({String label, bool enabled, VoidCallback onPressed})? main;
    switch (s.step) {
      case SplitStep.start || SplitStep.reading:
        return null;
      case SplitStep.people:
        if (s.error != null) return null;
        final count = s.people.length + 1;
        caption = count == 1 ? '1 person' : '$count people';
        value = ['Me', for (final p in s.people) p.name].join(', ');
        main = (label: 'Next', enabled: true, onPressed: vm.next);
      case SplitStep.items:
        final total = SplitEditorViewModel.totalOf(s);
        final missing = SplitEditorViewModel.unassigned(s).length;
        caption = 'Total';
        value = total == null ? 'Check the amounts' : splitRm(total);
        hint = switch (missing) {
          0 => null,
          1 => '1 item has no one yet. Pick someone to go on.',
          final n => '$n items have no one yet. Pick someone to go on.',
        };
        main = (
          label: 'Next',
          enabled: s.items.isNotEmpty && total != null && missing == 0,
          onPressed: vm.next,
        );
      case SplitStep.link:
        main = s.locked
            ? (
                label: 'Save payment',
                enabled: true,
                onPressed: vm.saveLockedPayment,
              )
            : (label: 'Next', enabled: true, onPressed: vm.next);
      case SplitStep.summary:
        final viewed = s.billId != null && !s.editing && s.amounts == null;
        second = OutlinedButton.icon(
          onPressed: SplitEditorViewModel.shareText(s) == null ? null : _share,
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Send summary'),
        );
        main = s.locked
            ? null
            : (
                label: viewed ? 'Done' : 'Save split',
                enabled:
                    s.amounts == null ||
                    SplitEditorViewModel.amountsLeft(s)?.sign == 0,
                onPressed: vm.done,
              );
    }
    final mainButton = main == null
        ? null
        : FilledButton(
            onPressed: main.enabled && !s.saving ? main.onPressed : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 56),
              padding: const EdgeInsets.symmetric(horizontal: 28),
            ),
            child: Text(main.label),
          );
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (second != null) ...[
                    Expanded(child: second),
                    if (mainButton != null) const SizedBox(width: 12),
                  ] else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (caption != null)
                            Text(
                              caption,
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (value != null)
                            Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tabular(theme.textTheme.titleMedium!),
                            ),
                        ],
                      ),
                    ),
                  if (mainButton != null)
                    second != null ? Expanded(child: mainButton) : mainButton,
                ],
              ),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    hint,
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
    );
  }
}

/// "2 of 3" in the title row of the band.
class _StepPill extends StatelessWidget {
  const _StepPill(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Step $number of 3',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: ShapeDecoration(
          color: theme.colorScheme.surfaceContainer,
          shape: const StadiumBorder(),
        ),
        child: Text(
          '$number of 3',
          style: tabular(theme.textTheme.labelLarge!),
        ),
      ),
    );
  }
}

class _StartStep extends StatefulWidget {
  const _StartStep({
    required this.state,
    required this.vm,
    required this.onTypeItems,
  });

  final SplitEditorState state;
  final SplitEditorViewModel vm;
  final void Function([RecentItem? prefill]) onTypeItems;

  @override
  State<_StartStep> createState() => _StartStepState();
}

class _StartStepState extends State<_StartStep> {
  bool _picking = false;

  /// Opens a photo source and reads the photo it gives. A cancel gives null and changes nothing.
  /// As in 0.1.1, a failed photo shows nothing: the editor stays on the start step.
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
  Future<void> _splitEvenly() async {
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
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final payment = widget.state.linkedPayment;
    final shop = payment?.merchant?.trim() ?? '';
    final recent = shop.isEmpty
        ? const <RecentItem>[]
        : widget.vm.recentItems
              .where(
                (i) => i.merchant?.trim().toLowerCase() == shop.toLowerCase(),
              )
              .take(8)
              .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        if (payment != null) ...[
          PaymentCard(payment),
          const SizedBox(height: KobanSpace.s12),
        ],
        SplitCard(
          children: [
            FilledButton.icon(
              onPressed: _picking
                  ? null
                  : () => _pick(AppScope.of(context).receiptPhotos.scan),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              icon: const Icon(Icons.camera_alt, size: 20),
              label: const Text('Scan receipt'),
            ),
            const SizedBox(height: KobanSpace.s8),
            OutlinedButton.icon(
              onPressed: _picking
                  ? null
                  : () => _pick(AppScope.of(context).pickImage),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.image, size: 18),
              label: const Text('Choose from gallery'),
            ),
            const SizedBox(height: KobanSpace.s12),
            Text(
              widget.state.onlineAccess
                  ? "Koban reads the items on your phone and with Claude. The photo goes to Koban's server, which deletes it after reading."
                  : 'Koban reads the items on your phone. The photo is not sent anywhere.',
              style: muted,
            ),
          ],
        ),
        const SizedBox(height: KobanSpace.s12),
        ListGroup(
          children: [
            KobanRow(
              title: payment == null
                  ? 'Type the total and split evenly'
                  : 'Split ${splitRm(payment.amount)} evenly',
              subtitle: 'No items. Everyone pays the same.',
              leading: const Icon(Icons.call_split),
              showChevron: true,
              onTap: _picking ? null : _splitEvenly,
            ),
            KobanRow(
              title: 'Type items',
              subtitle: 'A keypad, recent items, and who had what.',
              leading: const Icon(Icons.dialpad),
              showChevron: true,
              onTap: _picking ? null : widget.onTypeItems,
            ),
          ],
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: KobanSpace.s12),
          SplitCard(
            children: [
              CardHeading('Recent at $shop'),
              const SizedBox(height: 4),
              Text(
                'Tap one to start typing items with it. Name and price fill in.',
                style: muted,
              ),
              const SizedBox(height: KobanSpace.s8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in recent)
                    ActionChip(
                      onPressed: () => widget.onTypeItems(i),
                      label: Text('${i.name} · ${splitRm(i.unitPrice)}'),
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
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
    return SplitCard(
      side: BorderSide(color: review),
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
    );
  }
}

/// The Fix sheet of 0.1.1. It closes when no mismatch is left and Claude does not read.
Future<void> showFixSheet(BuildContext context, SplitEditorViewModel vm) =>
    showKobanSheet<void>(
      context: context,
      isScrollControlled: false,
      showDragHandle: false,
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
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

/// Opens the people of the split over the items, to add or remove someone.
Future<void> _showPeopleSheet(BuildContext context, SplitEditorViewModel vm) =>
    showKobanSheet<void>(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: vm,
        builder: (_, _) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: PeopleStep(state: vm.state, vm: vm, inSheet: true),
        ),
      ),
    );

class _ItemsStep extends StatelessWidget {
  const _ItemsStep({required this.state, required this.vm});

  final SplitEditorState state;
  final SplitEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final total = SplitEditorViewModel.totalOf(state);
    final diff = SplitEditorViewModel.difference(state);
    final printed = state.printedTotal;
    final message = state.message;
    final missing = SplitEditorViewModel.unassigned(state);
    const gap = SizedBox(height: KobanSpace.s12);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        SplitCard(
          children: [
            if (state.readSource != null) ...[
              Row(
                children: [
                  Icon(Icons.check, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.readSource!, style: muted)),
                ],
              ),
              gap,
            ],
            if (message != null) ...[
              Text(
                message,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: scheme.error,
                ),
              ),
              gap,
            ],
            if (state.readNote != null && diff == null) ...[
              Text(state.readNote!, style: muted),
              gap,
            ],
            SplitField(
              label: 'Shop',
              value: state.merchant,
              onChanged: vm.setMerchant,
            ),
          ],
        ),
        if (diff != null) ...[
          gap,
          MismatchCard(
            diff: diff,
            total: total,
            printed: printed,
            onFix: () => showFixSheet(context, vm),
          ),
        ],
        if (SplitEditorViewModel.targetTotal(state) != null) ...[
          gap,
          _Meter(state: state, vm: vm),
        ],
        gap,
        SplitCard(
          children: [
            CardHeading(
              'Items',
              trailing: TextButton.icon(
                onPressed: () => showItemSheet(context, vm),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add item'),
              ),
            ),
            if (state.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No items yet.', style: muted),
              ),
            for (final row in state.items)
              _ItemLine(
                key: ValueKey(row.key),
                row: row,
                state: state,
                unassigned: missing.contains(row.key),
                vm: vm,
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (state.items.isNotEmpty)
                  TextButton(
                    onPressed: vm.splitEverythingEvenly,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('Split everything evenly'),
                  ),
                TextButton.icon(
                  onPressed: () => _showPeopleSheet(context, vm),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.group, size: 18),
                  label: const Text('Edit people'),
                ),
              ],
            ),
          ],
        ),
        gap,
        _Charges(state: state, vm: vm),
      ],
    );
  }
}

/// How much of the receipt or payment the items cover, and one tap for the rest.
class _Meter extends StatelessWidget {
  const _Meter({required this.state, required this.vm});

  final SplitEditorState state;
  final SplitEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sum = SplitEditorViewModel.itemsSum(state);
    final rest = SplitEditorViewModel.missingItemsOf(state);
    if (sum == null || rest == null) return const SizedBox.shrink();
    final target = sum + rest;
    final parts = SplitEditorViewModel.everyone(state).length;
    final fill = target.sign <= 0
        ? 1.0
        : (sum.toDouble() / target.toDouble()).clamp(0.0, 1.0);
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return SplitCard(
      children: [
        Text('Items typed', style: muted),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: splitRm(sum),
                style: tabular(theme.textTheme.titleLarge!),
              ),
              TextSpan(text: ' of ${splitRm(target)}', style: muted),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(KobanRadius.full),
          child: LinearProgressIndicator(
            value: fill,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHigh,
          ),
        ),
        const SizedBox(height: 8),
        if (rest.sign > 0) ...[
          Text('${splitRm(rest)} left, on no one yet', style: muted),
          const SizedBox(height: 8),
          TonalButton(
            'Split the rest evenly · ${splitRm(eachOf(rest, parts))} each',
            vm.splitTheRest,
          ),
        ] else if (rest.sign < 0)
          Text(
            '${splitRm(-rest)} more than the ${state.printedTotal == null ? 'payment' : 'receipt'}',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: MoneyColors.of(context).review,
            ),
          )
        else
          Text('Every sen of the bill is in the items.', style: muted),
      ],
    );
  }
}

/// One item: name, quantity and line price, and a face for each person. A tap edits it.
class _ItemLine extends StatelessWidget {
  const _ItemLine({
    super.key,
    required this.row,
    required this.state,
    required this.unassigned,
    required this.vm,
  });

  final ItemRow row;
  final SplitEditorState state;
  final bool unassigned;
  final SplitEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quantity = row.quantity.trim();
    final price = AmountFormatter.parseInput(row.price);
    final name = quantity == '1' ? row.name : '${row.name} ×$quantity';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        InkWell(
          onTap: () => showItemSheet(context, vm, row: row),
          child: Semantics(
            button: true,
            label: 'Edit ${row.name}',
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Expanded(
                    child: Text(name, style: theme.textTheme.titleMedium),
                  ),
                  if (price != null)
                    MoneyText(
                      splitRm(price),
                      style: theme.textTheme.titleMedium,
                    ),
                ],
              ),
            ),
          ),
        ),
        Wrap(
          children: [
            PersonToggle(
              'Me',
              on: row.sharedBy.contains(meId),
              onTap: () => vm.toggleShare(row.key, meId),
            ),
            for (final p in state.people)
              PersonToggle(
                p.name,
                on: row.sharedBy.contains(p.id),
                onTap: () => vm.toggleShare(row.key, p.id),
              ),
          ],
        ),
        if (unassigned)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Pick who had this item.',
              style: theme.textTheme.bodySmall!.copyWith(
                color: MoneyColors.of(context).review,
              ),
            ),
          ),
      ],
    );
  }
}

/// Service charge and SST as rate chips with the RM shown, then discount and rounding.
class _Charges extends StatelessWidget {
  const _Charges({required this.state, required this.vm});

  final SplitEditorState state;
  final SplitEditorViewModel vm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal = SplitEditorViewModel.itemsSum(state) ?? Decimal.zero;
    final printed = state.printedTotal;
    final rounding = state.rounding;
    final auto = rounding.trim().isEmpty
        ? SplitEditorViewModel.roundingOf(state)
        : null;
    Widget rateChip(
      String label,
      Charge current,
      int percent,
      ValueChanged<Charge> set,
    ) {
      final on = current == RateCharge(percent);
      return FilterChip(
        selected: on,
        onSelected: (_) => set(on ? const NoCharge() : RateCharge(percent)),
        label: Text(
          on
              ? '$label $percent% · ${splitRm(rateOf(subtotal, percent))}'
              : '$label $percent%',
        ),
      );
    }

    Widget? fixedChip(String label, Charge current, ValueChanged<Charge> set) =>
        current is FixedCharge
        ? FilterChip(
            selected: true,
            onSelected: (_) => set(const NoCharge()),
            label: Text('$label · ${splitRm(current.amount)}'),
          )
        : null;

    return SplitCard(
      children: [
        CardHeading(
          'Charges',
          trailing: printed == null
              ? null
              : Text(
                  'Receipt total ${splitRm(printed)}',
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
        const SizedBox(height: KobanSpace.s8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in serviceRates)
              rateChip('Service charge', state.service, r, vm.setService),
            ?fixedChip('Service charge', state.service, vm.setService),
            for (final r in sstRates) rateChip('SST', state.tax, r, vm.setTax),
            ?fixedChip('SST', state.tax, vm.setTax),
          ],
        ),
        const SizedBox(height: KobanSpace.s16),
        SplitField(
          label: 'Discount (RM)',
          value: state.discount,
          onChanged: vm.setDiscount,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          isError:
              state.discount.trim().isNotEmpty &&
              AmountFormatter.parseInput(state.discount) == null,
        ),
        const SizedBox(height: KobanSpace.s12),
        SplitField(
          label: 'Rounding (RM)',
          value: rounding,
          onChanged: vm.setRounding,
          keyboard: TextInputType.text,
          hint: auto != null && auto.sign != 0 && printed != null
              ? 'Set to ${AmountFormatter.formatDisplay(auto)} to match ${splitRm(printed)}'
              : 'Use - for a negative amount',
          isError:
              rounding.trim().isNotEmpty &&
              AmountFormatter.parseInput(rounding) == null,
        ),
      ],
    );
  }
}
