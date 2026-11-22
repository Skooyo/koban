import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../rules/top_up.dart';
import '../../theme/mon.dart';
import '../../ui/alerts_off_row.dart';
import '../../ui/kit.dart';
import '../payment/category_sheet.dart';
import 'check_payment_card.dart';
import 'check_payments_view_model.dart';

// Drag distances from the approved prototype (`CheckPaymentsScreen.kt`).
const _stampFullAt = 90.0;
const _commitAt = 100.0;
const _flyTo = 520.0;
const _tiltPerDegree = 18.0;
const _stackDepth = 3;
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

/// The swipe screen for waiting payments: save or drop each card, with Undo.
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

  /// The drag of the top card in dp. The fly-out and the spring-back move it too.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  late final Animation<double> _stamp = _offset.drive(
    Tween(begin: 0.0, end: 1 / _stampFullAt),
  );

  String? _topId;
  bool _flying = false;
  bool _closed = false;
  int _snackBars = 0;
  bool _alertsOff = false;

  @override
  void initState() {
    super.initState();
    // Leaving the app commits the held swipe at once, so nothing waits on a hidden screen.
    _lifecycle = AppLifecycleListener(
      onHide: () => _vm?.flushHold(),
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
      _flying = false;
      _offset
        ..stop()
        ..value = 0;
    }
    // The Undo pill keeps the screen open for its 4 seconds, so the last card can still come back.
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

  Future<void> _decide({required bool save}) async {
    final top = _vm!.cards?.firstOrNull;
    if (top == null || _flying) return;
    // Save waits for a direction; the card springs back. Drop still works.
    if (save && top.payment.directionUnclear) {
      _springBack();
      if (_snackBars == 0) _showMessage(_chooseDirectionMessage);
      return;
    }
    setState(() => _flying = true);
    if (!_reduceMotion) {
      await _offset.animateTo(
        save ? _flyTo : -_flyTo,
        duration: _move,
        curve: Curves.fastOutSlowIn,
      );
    }
    if (mounted) _vm!.swipe(top.payment.id, save: save);
  }

  void _onDragEnd(DragEndDetails _) {
    final dx = _offset.value;
    if (dx.abs() > _commitAt) {
      _decide(save: dx > 0);
    } else {
      _springBack();
    }
  }

  void _edit(CheckCard card) => showEditPaymentSheet(
    context,
    card: card,
    categories: _vm!.categories,
    onSave: _vm!.edit,
  );

  void _setCategory(CheckCard card, String? id) =>
      _vm!.edit(card.payment.copyWith(categoryId: Value(id)));

  void _pickCategory(CheckCard card) => showCategorySheet(
    context,
    categories: _vm!.categories,
    selectedId: card.categoryId,
    mostUsedIds: _vm!.mostUsedIds,
    onPick: (id) => _setCategory(card, id),
  );

  @override
  Widget build(BuildContext context) {
    final vm = _vm!;
    final cards = vm.cards;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final muted = scheme.onSurfaceVariant;
    if (cards == null) {
      // Empty while the cards load. A failed load shows its text and Back.
      final error = vm.loadError;
      if (error == null) return const Scaffold();
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: WarningRow(error),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final top = cards.firstOrNull;
    final shown = cards.take(_stackDepth).toList();
    final label = vm.undoLabel;
    // A top-up is usually not a payment, so the gold button is Not a payment.
    final topUp =
        top != null && looksLikeTopUp(top.payment.rawNotificationText);
    const dropLabel = _ButtonLabel(Icons.close, 'Not a payment');
    const saveLabel = _ButtonLabel(Icons.check, 'Save payment');
    const buttonSize = Size(0, 52);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
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
                              'Check payments',
                              style: text.titleLarge,
                            ),
                          ),
                        ),
                      ),
                      if (top != null)
                        Text(
                          '${vm.handled + 1} of ${cards.length + vm.handled}',
                          style: text.bodyLarge!.copyWith(color: muted),
                        ),
                    ],
                  ),
                ),
                if (_alertsOff)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: AlertsOffRow(onTurnOn: _turnOnAlerts),
                  ),
                // The card takes the height it needs (up to all of it); the hint sits right under it.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      children: [
                        Flexible(
                          fit: top == null ? FlexFit.tight : FlexFit.loose,
                          child: Stack(
                            children: [
                              if (top == null)
                                const Center(child: _AllChecked()),
                              // Drawn back to front, so the oldest card is on top.
                              for (
                                var depth = shown.length - 1;
                                depth >= 0;
                                depth--
                              )
                                _stackCard(shown[depth], depth),
                            ],
                          ),
                        ),
                        if (top != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Text(
                              'Tap a field to fix it. Swipe right to save, left for Not a payment.',
                              style: text.bodyMedium!.copyWith(color: muted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (top != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: topUp
                              ? FilledButton(
                                  onPressed: () => _decide(save: false),
                                  style: FilledButton.styleFrom(
                                    minimumSize: buttonSize,
                                  ),
                                  child: dropLabel,
                                )
                              : OutlinedButton(
                                  onPressed: () => _decide(save: false),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: buttonSize,
                                  ),
                                  child: dropLabel,
                                ),
                        ),
                        Expanded(
                          child: topUp
                              ? OutlinedButton(
                                  onPressed: () => _decide(save: true),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: buttonSize,
                                  ),
                                  child: saveLabel,
                                )
                              : FilledButton(
                                  onPressed: () => _decide(save: true),
                                  style: FilledButton.styleFrom(
                                    minimumSize: buttonSize,
                                  ),
                                  child: saveLabel,
                                ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Back to Home'),
                    ),
                  ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 140,
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
    );
  }

  Widget _stackCard(CheckCard card, int depth) {
    final isTop = depth == 0;
    final payment = card.payment;
    final layered = TweenAnimationBuilder<double>(
      tween: Tween(end: depth.toDouble()),
      duration: _reduceMotion ? Duration.zero : _move,
      builder: (context, lift, child) => Transform.translate(
        offset: Offset(0, lift * 10),
        child: Transform.scale(
          scale: 1 - lift * 0.04,
          child: isTop
              ? child
              : Opacity(
                  opacity: (1 - lift * 0.25).clamp(0.0, 1.0),
                  child: child,
                ),
        ),
      ),
      child: isTop
          ? AnimatedBuilder(
              animation: _offset,
              builder: (context, child) {
                final dx = _offset.value;
                return Transform.translate(
                  offset: Offset(dx, 0),
                  child: Transform.rotate(
                    angle: dx / _tiltPerDegree * math.pi / 180,
                    child: Opacity(
                      opacity: _flying
                          ? (1 - dx.abs() / _flyTo).clamp(0.0, 1.0)
                          : 1,
                      child: child,
                    ),
                  ),
                );
              },
              child: CheckPaymentCard(
                card: card,
                stamp: _stamp,
                onEdit: () => _edit(card),
                onChooseDirection: (type) => _vm!.edit(
                  payment.copyWith(
                    transactionType: type,
                    directionUnclear: false,
                  ),
                ),
                onPickCategory: () => _pickCategory(card),
              ),
            )
          : CheckPaymentCard(card: card),
    );
    // One widget shape for every depth, so a card keeps its lift animation when it moves up.
    // The drag sits outside the layer, so the tilt does not skew the drag distance.
    return GestureDetector(
      key: ValueKey(payment.id),
      onHorizontalDragStart: isTop && !_flying ? (_) => _offset.stop() : null,
      onHorizontalDragUpdate: isTop && !_flying
          ? (d) => _offset.value += d.delta.dx
          : null,
      onHorizontalDragEnd: isTop && !_flying ? _onDragEnd : null,
      child: Semantics(
        container: isTop,
        // No Save while the direction is unclear; the Spent and Received buttons come first.
        customSemanticsActions: isTop
            ? {
                if (!payment.directionUnclear)
                  _saveAction: () => _decide(save: true),
                _dropAction: () => _decide(save: false),
              }
            : null,
        child: ExcludeSemantics(excluding: !isTop, child: layered),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 8),
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
        const Mon(MonFace.happy, size: 120),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text('All checked', style: theme.textTheme.headlineMedium),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Nothing left. I will just sit here and shine.',
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

/// "Saved Kedai Contoh · Undo" in inverse colors. A tap undoes the swipe.
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
