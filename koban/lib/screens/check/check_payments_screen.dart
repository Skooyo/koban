import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../rules/top_up.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
import '../../ui/alerts_off_row.dart';
import '../../ui/kit.dart';
import '../../ui/scene_band.dart';
import '../payment/category_sheet.dart';
import 'check_payment_card.dart';
import 'check_payments_view_model.dart';

// Drag distances from the approved prototype (`CheckPaymentsScreen.kt`).
const _commitAt = 100.0;
const _flyTo = 520.0;
const _move = Duration(milliseconds: 250);
const _chooseDirectionMessage = 'Choose Spent or Received first.';

/// The Compose default spring: no bounce, medium stiffness.
final _spring = SpringDescription.withDampingRatio(
  mass: 1,
  stiffness: 1500,
  ratio: 1,
);

const _saveAction = CustomSemanticsAction(label: 'Save');
const _dropAction = CustomSemanticsAction(label: 'Not a payment');

/// Waiting payments, one flat card at a time: save or drop each, or save all, with Undo.
class CheckPaymentsScreen extends StatefulWidget {
  const CheckPaymentsScreen({super.key});

  @override
  State<CheckPaymentsScreen> createState() => _CheckPaymentsScreenState();
}

class _CheckPaymentsScreenState extends State<CheckPaymentsScreen>
    with SingleTickerProviderStateMixin {
  CheckPaymentsViewModel? _vm;
  StreamSubscription<String>? _messages;
  late final AppLifecycleListener _lifecycle;

  /// The drag of the card in dp. The fly-out and the spring-back move it too.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );

  String? _topId;

  /// The top card's state. A new key for each card, so its typed text starts fresh.
  var _cardState = GlobalKey<CheckPaymentCardState>();
  bool _flying = false;
  bool _closed = false;
  int _snackBars = 0;
  bool _alertsOff = false;

  @override
  void initState() {
    super.initState();
    // Leaving the app commits the held swipe at once, so nothing waits on a hidden screen.
    _lifecycle = AppLifecycleListener(
      onHide: () {
        // Typed text first, so the held swipe commits with it.
        _cardState.currentState?.flush();
        _vm?.flushHold();
      },
      onResume: _readAlerts,
    );
  }

  Future<void> _readAlerts() async {
    final off = await alertsBlocked(AppScope.of(context).device);
    if (mounted && off != _alertsOff) setState(() => _alertsOff = off);
  }

  Future<void> _turnOnAlerts() async {
    await turnOnAlerts(AppScope.of(context).device);
    if (mounted) await _readAlerts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm == null) {
      final vm = _vm = CheckPaymentsViewModel(AppScope.of(context))
        ..addListener(_onChange);
      _messages = vm.messages.listen(_showMessage);
      _readAlerts();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _messages?.cancel();
    // Back commits the held swipe: the view-model does it when it goes.
    _vm!
      ..removeListener(_onChange)
      ..dispose();
    _offset.dispose();
    super.dispose();
  }

  void _onChange() {
    final vm = _vm!;
    final cards = vm.cards;
    final topId = cards?.firstOrNull?.payment.id;
    if (topId != _topId) {
      _topId = topId;
      _cardState = GlobalKey();
      _flying = false;
      _offset
        ..stop()
        ..value = 0;
    }
    // The Undo pill keeps the screen open for its 6 seconds, so the last card can still come back.
    if (cards != null && cards.isEmpty && vm.undoLabel == null) _close();
    setState(() {});
  }

  void _close() {
    if (_closed || ModalRoute.of(context)?.isCurrent != true) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _showMessage(String message) {
    _snackBars++;
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        )
        .closed
        .then((_) => _snackBars--);
  }

  void _springBack() {
    if (_reduceMotion) {
      _offset.value = 0;
      return;
    }
    _offset
        .animateWith(SpringSimulation(_spring, _offset.value, 0, 0))
        .then((_) => _offset.value = 0);
  }

  /// Saves ([save] true) or drops the top card, or with [all] saves every card.
  Future<void> _decide({required bool save, bool all = false}) async {
    final top = _vm!.cards?.firstOrNull;
    if (top == null || _flying) return;
    // Save waits for a direction; the card springs back. Drop still works.
    if (save && !all && top.payment.directionUnclear) {
      _springBack();
      if (_snackBars == 0) _showMessage(_chooseDirectionMessage);
      return;
    }
    // Typed text goes to the database first. A bad amount stops the save.
    if (save &&
        !await (_cardState.currentState?.flush() ?? Future.value(true))) {
      _springBack();
      return;
    }
    if (!mounted) return;
    setState(() => _flying = true);
    if (!_reduceMotion) {
      await _offset.animateTo(
        save ? _flyTo : -_flyTo,
        duration: _move,
        curve: Curves.fastOutSlowIn,
      );
    }
    if (!mounted) return;
    if (all) {
      _vm!.saveAll();
    } else {
      _vm!.swipe(top.payment.id, save: save);
    }
  }

  void _onDragEnd(DragEndDetails _) {
    final dx = _offset.value;
    if (dx.abs() > _commitAt) {
      _decide(save: dx > 0);
    } else {
      _springBack();
    }
  }

  void _pickCategory(CheckCard card) => showCategorySheet(
    context,
    categories: _vm!.categories,
    selectedId: card.categoryId,
    mostUsedIds: _vm!.mostUsedIds,
    onPick: (id) => _vm!.edit(card.payment.copyWith(categoryId: Value(id))),
  );

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final cards = vm.cards;
    if (cards == null) {
      // Empty while the cards load. A failed load shows its text and Back.
      final error = vm.loadError;
      return Scaffold(
        body: Column(
          children: [
            const TaskHeader(title: 'Check payments'),
            if (error == null)
              const LoadingLine()
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: WarningRow(error),
              ),
          ],
        ),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = cards.firstOrNull;
    final label = vm.undoLabel;
    // A top-up is usually not a payment, so the gold button is Not a payment.
    final topUp =
        top != null && looksLikeTopUp(top.payment.rawNotificationText);
    const buttonSize = Size.fromHeight(56);
    final total = cards.length + vm.handled;
    final after = cards.length - 1;
    final save = topUp
        ? OutlinedButton(
            onPressed: () => _decide(save: true),
            style: _outline(scheme),
            child: const _ButtonLabel(Icons.check, 'Save payment'),
          )
        : FilledButton(
            onPressed: () => _decide(save: true),
            style: FilledButton.styleFrom(minimumSize: buttonSize),
            child: const _ButtonLabel(Icons.check, 'Save payment'),
          );
    final drop = topUp
        ? FilledButton(
            onPressed: () => _decide(save: false),
            style: FilledButton.styleFrom(minimumSize: buttonSize),
            child: const _ButtonLabel(null, 'Not a payment'),
          )
        : OutlinedButton(
            onPressed: () => _decide(save: false),
            style: _outline(scheme),
            child: const _ButtonLabel(null, 'Not a payment'),
          );
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            TaskHeader(
              title: 'Check payments',
              action: top == null
                  ? null
                  : Text(
                      '${vm.handled + 1} of $total',
                      style: tabular(
                        theme.textTheme.labelLarge!.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
            ),
            if (_alertsOff)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: AlertsOffRow(onTurnOn: _turnOnAlerts),
              ),
            Expanded(
              child: Stack(
                children: [
                  if (top == null)
                    const Center(child: _AllChecked())
                  else
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        _alertsOff ? 12 : 16,
                        16,
                        16,
                      ),
                      child: _flatCard(top, vm),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 8,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: _reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: label == null
                            ? const SizedBox.shrink()
                            : _UndoPill(
                                key: const ValueKey('pill'),
                                label: label,
                                onTap: vm.undo,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (top != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: topUp ? [drop, save] : [save, drop],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        after == 0 ? 'Last one' : '$after more after this',
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (vm.canSaveAll)
                      TextButton(
                        onPressed: () => _decide(save: true, all: true),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        child: Text('Save all ${cards.length}'),
                      ),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: FilledButton.styleFrom(minimumSize: buttonSize),
                  child: const Text('Back to Home'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _outline(ColorScheme scheme) => OutlinedButton.styleFrom(
    minimumSize: const Size.fromHeight(56),
    foregroundColor: scheme.onSurface,
    side: BorderSide(color: scheme.onSurface, width: 2),
  );

  /// The card, with the swipe: right saves, left is Not a payment.
  Widget _flatCard(CheckCard card, CheckPaymentsViewModel vm) {
    final payment = card.payment;
    final swipeable = !_flying;
    return GestureDetector(
      key: ValueKey(payment.id),
      onHorizontalDragStart: swipeable ? (_) => _offset.stop() : null,
      onHorizontalDragUpdate: swipeable
          ? (d) => _offset.value += d.delta.dx
          : null,
      onHorizontalDragEnd: swipeable ? _onDragEnd : null,
      child: Semantics(
        container: true,
        // No Save while the direction is unclear; the Spent and Received buttons come first.
        customSemanticsActions: {
          if (!payment.directionUnclear) _saveAction: () => _decide(save: true),
          _dropAction: () => _decide(save: false),
        },
        child: AnimatedBuilder(
          animation: _offset,
          builder: (context, child) {
            final dx = _offset.value;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: Opacity(
                opacity: _flying ? (1 - dx.abs() / _flyTo).clamp(0.0, 1.0) : 1,
                child: child,
              ),
            );
          },
          child: CheckPaymentCard(
            key: _cardState,
            card: card,
            categories: vm.categories,
            mostUsedIds: vm.mostUsedIds,
            onEdit: vm.edit,
            onMoreCategories: () => _pickCategory(card),
          ),
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.icon, this.text);

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
      // No own style: the button's label style holds the right text color.
      Flexible(child: Text(text)),
    ],
  );
}

/// Shown while the Undo pill of the last card is open; the screen closes after it.
class _AllChecked extends StatelessWidget {
  const _AllChecked();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Mon(MonFace.happy, size: 72),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text('All checked', style: theme.textTheme.headlineMedium),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'That was the last one.',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// "Payment saved: Kedai Contoh · Undo" in inverse colors. A tap undoes the swipe.
class _UndoPill extends StatelessWidget {
  const _UndoPill({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      button: true,
      onTapHint: 'Undo',
      child: Material(
        color: scheme.inverseSurface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                label,
                style: weighted(
                  theme.textTheme.bodyLarge!,
                  700,
                ).copyWith(color: scheme.onInverseSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
