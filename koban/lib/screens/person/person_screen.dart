import 'dart:async';
import 'dart:developer' as developer;

import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../app/routes.dart';
import '../../data/database.dart';
import '../../data/people_repository.dart';
import '../../data/qr_store.dart';
import '../../data/split_repository.dart';
import '../../rules/amount_formatter.dart';
import '../../rules/people_math.dart';
import '../../theme/koban_theme.dart';
import '../../ui/date_labels.dart';
import '../../ui/kit.dart';
import '../../ui/money.dart';
import '../../ui/undo_snack_bar.dart';
import 'person_dialogs.dart';
import 'person_view_model.dart';

/// The page of one person: the payment QR, what each side owes, and settle up.
/// A port of `PersonScreen.kt` and `PersonDialogs.kt`.
class PersonScreen extends StatefulWidget {
  const PersonScreen(this.personId, {super.key});

  final String personId;

  @override
  State<PersonScreen> createState() => PersonScreenState();
}

class PersonScreenState extends State<PersonScreen> {
  PersonViewModel? _vm;
  StreamSubscription<String>? _messages;
  // Read early: a delete that closes this page still shows its snackbar.
  late ScaffoldMessengerState _messenger;
  bool _closing = false;
  bool _asking = false;

  /// The view-model of the screen. Tests read its state.
  @visibleForTesting
  PersonViewModel get viewModel => _vm!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
    if (_vm == null) {
      final vm = _vm = PersonViewModel(AppScope.of(context), widget.personId)
        ..addListener(_onChange);
      _messages = vm.messages.listen(_showMessage);
      vm.onUndo = (message, undo) =>
          showUndoSnackBar(_messenger, message, undo: undo);
    }
  }

  @override
  void dispose() {
    unawaited(_messages?.cancel());
    _vm
      ?..removeListener(_onChange)
      ..dispose();
    super.dispose();
  }

  void _onChange() {
    final vm = _vm!;
    if (vm.gone) _close();
    final paying = vm.paying;
    if (paying != null) unawaited(_askPayment(paying));
  }

  void _close() {
    if (_closing || !mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _closing = true;
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Shows one dialog at a time. A second tap while a dialog is open does nothing.
  Future<T?> _ask<T>(Future<T> Function() show) async {
    if (_asking) return null;
    _asking = true;
    try {
      return await show();
    } finally {
      _asking = false;
    }
  }

  Future<void> _askPayment(DebtPayment paying) async {
    if (_asking) return;
    final vm = _vm!;
    await _ask(
      () => showDebtPaymentDialog(context, paying, onPick: vm.markDebtPaid),
    );
    // Cancel or a tap outside: the dialog closed with the debt still chosen.
    if (mounted && vm.paying != null) vm.cancelPaying();
  }

  Future<void> _rename(String name) =>
      _ask(() => showRenameDialog(context, name: name, onSave: _vm!.rename));

  void _delete(String name) => _vm!.delete('$name deleted');

  Future<void> _settleUp(PersonDetail d) async {
    final ok = await _ask(
      () => showSettleUpDialog(
        context,
        name: d.person.name,
        debtCount: d.owedToMe.length,
        itemCount: d.iOwe.length,
      ),
    );
    if (ok == true) _vm!.settleUp();
  }

  Future<void> _addItem() => _ask(
    () => showOwedItemDialog(
      context,
      title: 'Add what I owe',
      onSave: _vm!.addItem,
    ),
  );

  Future<void> _addOwedToMe(String name) => _ask(
    () => showOwedItemDialog(
      context,
      title: 'Add what $name owes me',
      onSave: _vm!.addOwedToMe,
    ),
  );

  Future<void> _openDebt(OpenDebtView view, String name) async {
    if (!view.manual) {
      return _ask(() => openSplitEdit(context, view.debt.billId));
    }
    final vm = _vm!;
    final result = await _ask(
      () => showOwedItemDialog(
        context,
        title: 'Edit what $name owes me',
        description: view.billMerchant ?? '',
        amount: view.debt.amount,
        itemDate: view.billTime,
        canDelete: true,
        onSave: (description, amount, itemDate) =>
            vm.updateOwedToMe(view.debt.id, description, amount, itemDate),
      ),
    );
    if (result != OwedItemResult.delete) return;
    vm.deleteOwedToMe(
      view.debt.id,
      'Item deleted: ${view.billMerchant ?? name}, ${rm(view.debt.amount)}',
    );
  }

  Future<void> _editItem(OwedItem item) async {
    final vm = _vm!;
    final result = await _ask(
      () => showOwedItemDialog(
        context,
        title: 'Edit what I owe',
        description: item.description,
        amount: item.amount,
        itemDate: item.itemDate,
        canDelete: true,
        onSave: (description, amount, itemDate) => vm.updateItem(
          item.copyWith(
            description: description,
            amount: amount,
            itemDate: itemDate,
          ),
        ),
      ),
    );
    if (result != OwedItemResult.delete) return;
    vm.deleteItem(
      item.id,
      'Item deleted: ${item.description}, ${rm(item.amount)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final detail = vm.detail;
        final name = detail?.person.name ?? '';
        final hasQr = detail?.person.qrPath != null;
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Semantics(
                            header: true,
                            child: Text(
                              name,
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                        ),
                      ),
                      if (detail != null)
                        PopupMenuButton<VoidCallback>(
                          tooltip: 'More options',
                          icon: const Icon(Icons.more_vert),
                          onSelected: (action) => action(),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: () => _rename(name),
                              child: const Text('Rename'),
                            ),
                            if (hasQr)
                              PopupMenuItem(
                                value: vm.pickQr,
                                child: const Text('Replace QR'),
                              ),
                            PopupMenuItem(
                              value: () => _delete(name),
                              child: const Text('Delete person'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (detail != null)
                  Expanded(child: _content(context, vm, detail)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, PersonViewModel vm, PersonDetail d) {
    final name = d.person.name;
    final qrPath = d.person.qrPath;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _BalanceCard(
          name: name,
          balance: d.balance,
          bills: d.balance is YouPay ? d.iOwe.length : d.owedToMe.length,
          oldest: _oldest(d),
          onRemind: () => _remind(d),
          onSettleUp: () => _settleUp(d),
        ),
        if (d.settleSuggestion case final receive?) ...[
          const SizedBox(height: 16),
          _RepaymentCard(
            title: 'Possible settle up',
            text: receiveText(receive),
            onConfirm: vm.confirmSettle,
            onDismiss: vm.dismissSettle,
          ),
        ],
        const SizedBox(height: 24),
        SectionHeading('$name owes you'),
        if (d.owedToMe.isEmpty)
          const _Nothing()
        else
          ListGroup(
            children: [
              for (final view in d.owedToMe)
                _DebtRow(
                  key: ValueKey(view.debt.id),
                  view: view,
                  onOpen: () => _openDebt(view, name),
                  onMarkPaid: () => vm.startPaying(view),
                  onConfirm: () => vm.confirmDebtSuggestion(view.debt.id),
                  onDismiss: () => vm.dismissDebtSuggestion(view.debt.id),
                ),
            ],
          ),
        _AddButton('Add what $name owes me', () => _addOwedToMe(name)),
        const SizedBox(height: 16),
        SectionHeading('You owe $name'),
        if (d.iOwe.isEmpty)
          const _Nothing()
        else
          ListGroup(
            children: [
              for (final item in d.iOwe)
                _ItemRow(
                  key: ValueKey(item.id),
                  item: item,
                  onEdit: () => _editItem(item),
                  onMarkPaid: () => vm.markItemPaid(item.id),
                ),
            ],
          ),
        _AddButton('Add what I owe', _addItem),
        const SizedBox(height: 16),
        ListGroup(
          children: [
            KobanRow(
              title: "$name's payment QR",
              subtitle: qrPath == null ? 'Not added yet. Tap to add it.' : null,
              leading: const Icon(Icons.qr_code_2),
              showChevron: true,
              onTap: qrPath == null
                  ? vm.pickQr
                  : () => _showQr(vm, name, qrPath),
              onTapLabel: qrPath == null ? 'Add QR' : 'Open QR',
            ),
          ],
        ),
      ],
    );
  }

  /// The oldest date among the open bills of the side that the balance card counts.
  int? _oldest(PersonDetail d) {
    final times = d.balance is YouPay
        ? [for (final i in d.iOwe) i.itemDate]
        : [for (final v in d.owedToMe) v.billTime];
    return times.isEmpty ? null : times.reduce((a, b) => a < b ? a : b);
  }

  Future<void> _remind(PersonDetail d) async {
    final balance = d.balance;
    if (balance is! PaysYou) return;
    final n = d.owedToMe.length;
    try {
      await AppScope.of(context).device.shareText(
        'Hi ${d.person.name}, you owe me RM '
        '${AmountFormatter.formatGrouped(balance.amount)} for '
        '$n ${n == 1 ? 'bill' : 'bills'} (Koban).',
        chooserTitle: 'Send reminder',
      );
    } catch (e, s) {
      developer.log(
        'Send reminder failed',
        name: 'PersonScreen',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// The QR big, with Save QR to gallery. A tap on the QR itself replaces it.
  Future<void> _showQr(PersonViewModel vm, String name, String path) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => ListenableBuilder(
          listenable: vm,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _QrFrame(
                      name: name,
                      path: path,
                      version: vm.qrVersion,
                      onTap: vm.pickQr,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TonalButton(
                    'Save QR to gallery',
                    vm.saveQrToGallery,
                    icon: Icons.download,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Then open your bank app and pick it from the gallery',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// The QR on a white box with a gold frame. A tap adds or replaces it.
/// White stays white in the dark theme, so the QR scans.
class _QrFrame extends StatelessWidget {
  const _QrFrame({
    required this.name,
    required this.path,
    required this.version,
    required this.onTap,
  });

  final String name;
  final String? path;
  final int version;
  final VoidCallback onTap;

  Widget _square(String? text) => AspectRatio(
    aspectRatio: 1,
    child: text == null
        ? null
        : Center(
            child: Builder(
              builder: (context) => Text(
                text,
                style: Theme.of(context).textTheme.titleSmall!
                    .copyWith(color: Colors.black),
                textAlign: TextAlign.center,
              ),
            ),
          ),
  );

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 6),
    );
    return SizedBox(
      width: 240,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          onTapHint: path != null ? 'Replace QR' : 'Add QR',
          child: Material(
            color: Colors.white,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: shape,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: path == null
                    ? _square('Add their payment QR')
                    : Image(
                        image: qrImage(path),
                        key: ValueKey(version),
                        semanticLabel: "$name's payment QR",
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                        // Still loading: keep the square so the layout does not jump.
                        frameBuilder: (context, child, frame, sync) =>
                            frame == null && !sync
                            ? Stack(children: [_square(null), child])
                            : child,
                        errorBuilder: (context, error, stack) => _square(
                          "Couldn't load the QR. Tap to pick it again.",
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The balance first: who owes whom, the amount, and the one or two actions.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.name,
    required this.balance,
    required this.bills,
    required this.oldest,
    required this.onRemind,
    required this.onSettleUp,
  });

  final String name;
  final Balance balance;
  final int bills;
  final int? oldest;
  final VoidCallback onRemind;
  final VoidCallback onSettleUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final (label, amount) = switch (balance) {
      PaysYou(:final amount) => ('$name owes you', amount),
      YouPay(:final amount) => ('You owe $name', amount),
      _ => (PeopleMath.headline(name, balance), null),
    };
    final oldest = this.oldest;
    final now = AppScope.of(context).now();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(
            label,
            style: amount == null
                ? weighted(theme.textTheme.titleLarge!, 700)
                : muted,
          ),
          if (amount != null) ...[
            MoneyText(
              balance is PaysYou ? '+ ${rm(amount)}' : rm(amount),
              style: theme.textTheme.displayMedium,
              color: balance is PaysYou
                  ? MoneyColors.of(context).received
                  : scheme.onSurface,
            ),
            if (oldest != null)
              Text(
                'From $bills split ${bills == 1 ? 'bill' : 'bills'}. '
                'Oldest: ${dateLabel(oldest, now)}.',
                style: muted,
              ),
          ],
          if (balance is! AllPaid) ...[
            const SizedBox(height: 4),
            if (balance is PaysYou) ...[
              FilledButton.icon(
                onPressed: onRemind,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Send reminder'),
              ),
              OutlinedButton(
                onPressed: onSettleUp,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Settle up'),
              ),
            ] else
              FilledButton(
                onPressed: onSettleUp,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Settle up'),
              ),
          ],
        ],
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing();

  @override
  Widget build(BuildContext context) => Text(
    'Nothing.',
    style: Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _AddButton extends StatelessWidget {
  const _AddButton(this.text, this.onPressed);

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
      icon: const Icon(Icons.add, size: 18),
      label: Text(text),
    ),
  );
}

/// A possible match for a received payment: gold outline, Confirm (tonal) and Not this (text).
class _RepaymentCard extends StatelessWidget {
  const _RepaymentCard({
    required this.title,
    required this.text,
    required this.onConfirm,
    required this.onDismiss,
  });

  final String title;
  final String text;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(Icons.info, color: scheme.primary, size: 20),
              Expanded(
                child: Text(
                  title,
                  style: weighted(theme.textTheme.titleMedium!, 700),
                ),
              ),
            ],
          ),
          Text(
            text,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                child: const Text('Not this'),
              ),
              TonalButton('Confirm', onConfirm),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarkPaidButton extends StatelessWidget {
  const _MarkPaidButton(this.onPressed);

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
        child: const Text('Mark paid'),
      ),
    ),
  );
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({
    super.key,
    required this.view,
    required this.onOpen,
    required this.onMarkPaid,
    required this.onConfirm,
    required this.onDismiss,
  });

  final OpenDebtView view;
  final VoidCallback onOpen;
  final VoidCallback onMarkPaid;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final suggested = view.suggestedRepayment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KobanRow(
          title: view.billMerchant ?? 'Split bill',
          subtitle: personDate(view.billTime),
          trailing: MoneyAmount(
            amount: view.debt.amount,
            style: Theme.of(context).textTheme.titleMedium!,
            color: MoneyColors.of(context).received,
          ),
          onTap: onOpen,
          onTapLabel: view.manual ? 'Edit' : 'Open split',
        ),
        _MarkPaidButton(onMarkPaid),
        if (suggested != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _RepaymentCard(
              title: 'Possible repayment',
              text: receiveText(suggested),
              onConfirm: onConfirm,
              onDismiss: onDismiss,
            ),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onMarkPaid,
  });

  final OwedItem item;
  final VoidCallback onEdit;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      KobanRow(
        title: item.description,
        subtitle: personDate(item.itemDate),
        trailing: MoneyAmount(
          amount: item.amount,
          style: Theme.of(context).textTheme.titleMedium!,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: onEdit,
        onTapLabel: 'Edit',
      ),
      _MarkPaidButton(onMarkPaid),
    ],
  );
}
