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
import '../../theme/tokens.dart';
import '../../ui/money.dart';
import '../../ui/scene_band.dart';
import '../../ui/sheets.dart';
import '../../ui/undo_snack_bar.dart';
import 'person_dialogs.dart';
import 'person_view_model.dart';
import 'qr_widgets.dart';

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

  Future<void> _edit(String name) async {
    final result = await _ask(() => showEditPersonSheet(context, vm: _vm!));
    if (result == EditPersonResult.delete) _vm!.delete('$name deleted');
  }

  Future<void> _settleUp(PersonDetail d) async {
    final ok = await _ask(
      () => showSettleUpDialog(
        context,
        name: d.person.name,
        balance: d.balance,
        splits: [
          for (final v in d.owedToMe)
            if (!v.manual)
              '${v.billMerchant ?? 'Split'}, ${personDate(v.billTime)}',
        ],
        items: [
          for (final v in d.owedToMe)
            if (v.manual)
              '${v.billMerchant ?? 'Item'}, ${personDate(v.billTime)}',
          for (final i in d.iOwe) '${i.description}, ${personDate(i.itemDate)}',
        ],
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
      title: 'Add what $name owes you',
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
        title: 'Edit what $name owes you',
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
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final detail = vm.detail;
        final name = detail?.person.name ?? '';
        final edit = detail == null
            ? null
            : SceneIconButton(
                icon: Icons.edit,
                tooltip: 'Edit $name',
                onPressed: () => _edit(name),
              );
        return Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              TaskHeader(title: name, action: edit),
              if (detail != null)
                _content(context, vm, detail)
              else if (vm.loadError case final error?)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: WarningRow(error),
                )
              else if (!vm.gone)
                const LoadingLine(),
            ],
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, PersonViewModel vm, PersonDetail d) {
    final name = d.person.name;
    final qrPath = d.person.qrPath;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              title: 'Settle up?',
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
          _AddButton('Add what $name owes you', () => _addOwedToMe(name)),
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
                    onMarkPaid: () => vm.markItemPaid(
                      item.id,
                      'Marked paid: ${item.description}',
                    ),
                  ),
              ],
            ),
          _AddButton('Add what I owe', _addItem),
          const SizedBox(height: 16),
          ListGroup(
            children: [
              KobanRow(
                title: "$name's payment QR",
                subtitle: qrPath == null
                    ? 'Not added yet.'
                    : qrAddedText(vm.qrAddedAt, AppScope.of(context).now()),
                leading: qrPath == null
                    ? const Icon(Icons.qr_code_2)
                    : QrThumb(image: qrImage(qrPath), version: vm.qrVersion),
                showChevron: true,
                onTap: qrPath == null
                    ? () => replaceQrOnPage(context, _messenger, vm, name)
                    : () => _showQr(vm, name, qrPath),
                onTapLabel: qrPath == null ? 'Add QR' : 'Open QR',
              ),
              _RowButton(
                qrPath == null ? 'Add QR' : 'Replace QR',
                () => replaceQrOnPage(context, _messenger, vm, name),
              ),
            ],
          ),
        ],
      ),
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
        '$n ${n == 1 ? 'split' : 'splits'} (Koban).',
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

  /// The QR big, with the 2 steps to pay, Save QR to gallery, Replace QR and Remove QR.
  /// Replace and Remove close the sheet first, so their snackbar with Undo shows on the page.
  Future<void> _showQr(PersonViewModel vm, String name, String path) {
    vm.clearQrNotices();
    return showKobanSheet<void>(
      context: context,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        return ListenableBuilder(
          listenable: vm,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'Pay $name',
                      style: weighted(theme.textTheme.titleLarge!, 800),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: QrFrame(
                      image: qrImage(path),
                      label: "$name's payment QR",
                      version: vm.qrVersion,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _Step(1, 'Save the QR to your gallery.'),
                  const _Step(
                    2,
                    'In your bank app, tap Scan, then pick the QR from the gallery.',
                  ),
                  const SizedBox(height: 12),
                  TonalButton(
                    'Save QR to gallery',
                    vm.saveQrToGallery,
                    icon: Icons.download,
                  ),
                  if (vm.storageDenied)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            storageRefused,
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => unawaited(
                            AppScope.of(sheet).device.openAppInfo(),
                          ),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text('Open settings'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      unawaited(
                        replaceQrOnPage(this.context, _messenger, vm, name),
                      );
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                    child: const Text('Replace QR'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheet);
                      vm.removeQr();
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Remove QR'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One numbered step: a number in a gold disc, then the text.
class _Step extends StatelessWidget {
  const _Step(this.number, this.text);

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: 'Step $number: $text',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                '$number',
                style: theme.textTheme.labelMedium!.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
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
        borderRadius: BorderRadius.circular(KobanRadius.r24),
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
                'From $bills ${bills == 1 ? 'split' : 'splits'}. '
                'Oldest: ${dateLabel(oldest, now)}.',
                style: muted,
              ),
          ],
          if (balance is PaysYou || balance is YouPay) ...[
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: const StadiumBorder(),
                color: scheme.primary,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Text(
                  'Possible payment',
                  style: theme.textTheme.labelMedium!.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: weighted(
                theme.textTheme.titleMedium!,
                700,
              ).copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
          Text(
            text,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: scheme.onPrimaryContainer,
                ),
                child: const Text('Not this'),
              ),
              FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  elevation: 0,
                  minimumSize: const Size(0, 48),
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A text button at the right end of a row, under what it acts on.
class _RowButton extends StatelessWidget {
  const _RowButton(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
        child: Text(label),
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
          title: view.billMerchant ?? 'Split',
          subtitle: personDate(view.billTime),
          trailing: MoneyAmount(
            amount: view.debt.amount,
            style: Theme.of(context).textTheme.titleMedium!,
            color: MoneyColors.of(context).received,
          ),
          onTap: onOpen,
          onTapLabel: view.manual ? 'Edit' : 'Open split',
        ),
        _RowButton('Mark paid', onMarkPaid),
        if (suggested != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _RepaymentCard(
              title: 'Mark paid?',
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
      _RowButton('Mark paid', onMarkPaid),
    ],
  );
}
