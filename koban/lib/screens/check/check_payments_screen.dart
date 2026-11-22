import 'dart:async';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../rules/top_up.dart';
import '../../rules/types.dart';
import '../../theme/koban_theme.dart';
import '../../theme/mon.dart';
import '../../ui/alerts_off_row.dart';
import '../../ui/kit.dart';
import '../../ui/scene_band.dart';
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
        body: Column(
          children: [
            const SceneBand(
              title: 'Check payments',
              face: MonFace.worry,
              line: 'That did not load.',
              back: true,
              compact: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
              child: WarningRow(error),
            ),
          ],
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
    final total = cards.length + vm.handled;
    final outline = OutlinedButton.styleFrom(
      minimumSize: buttonSize,
      foregroundColor: scheme.onSurface,
      side: BorderSide(color: scheme.onSurface, width: 2),
    );
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Column(
              children: [
                SceneBand(
                  title: 'Check payments',
                  face: top == null ? MonFace.happy : MonFace.idle,
                  line: top == null
                      ? 'That was the last one.'
                      : 'Is this one yours?',
                  detail: top == null ? null : _sourceLine(top),
                  back: true,
                  compact: true,
                  action: top == null
                      ? null
                      : _CounterPill('${vm.handled + 1} of $total'),
                ),
                if (_alertsOff)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                    child: AlertsOffRow(onTurnOn: _turnOnAlerts),
                  ),
                // The card takes the height it needs (up to a limit); the hint sits under it.
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      _alertsOff ? 12 : 8,
                      16,
                      0,
                    ),
                    child: Column(
                      children: [
                        Flexible(
                          fit: top == null ? FlexFit.tight : FlexFit.loose,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 560),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Stack(
                                clipBehavior: Clip.none,
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
                          ),
                        ),
                        if (top != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                            child: Text(
                              'Tap a field to fix it. Swipe right to save, left for Not a payment.',
                              style: text.bodySmall!.copyWith(color: muted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (top != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      spacing: 12,
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
                                  style: outline,
                                  child: dropLabel,
                                ),
                        ),
                        Expanded(
                          child: topUp
                              ? OutlinedButton(
                                  onPressed: () => _decide(save: true),
                                  style: outline,
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Back to Home'),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: top == null
                      ? const SizedBox(height: 20)
                      : _Progress(done: vm.handled, total: total),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
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

  /// Mon's second sentence: where the payment came from, and who decides.
  String _sourceLine(CheckCard card) {
    final p = card.payment;
    if (p.directionUnclear) return '${card.appName} is not sure. You decide.';
    final verb = p.transactionType == TransactionType.receive
        ? 'you received money'
        : 'you paid';
    return '${card.appName} says $verb. You decide.';
  }

  Widget _stackCard(CheckCard card, int depth) {
    final isTop = depth == 0;
    final payment = card.payment;
    final layered = TweenAnimationBuilder<double>(
      tween: Tween(end: depth.toDouble()),
      duration: _reduceMotion ? Duration.zero : _move,
      builder: (context, lift, child) => Transform.translate(
        offset: Offset(0, lift * 8),
        child: Transform.scale(
          scale: 1 - lift * 0.03,
          child: Transform.rotate(
            // The card behind leans left, the one behind that leans right.
            angle: _lean(lift) * math.pi / 180,
            child: _Tinted(lift: lift, child: child!),
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

/// The lean in degrees of a card [lift] places behind the top one.
double _lean(double lift) =>
    lift <= 1 ? -3 * lift : -3 + 7 * (lift - 1).clamp(0.0, 1.0);

/// Covers a card behind the top one with a teal, then a gold, tint.
/// The cover is solid at a lift of 1, so only the top card shows its text.
class _Tinted extends StatelessWidget {
  const _Tinted({required this.lift, required this.child});

  final double lift;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (lift <= 0) return child;
    final teal = SceneColors.of(context).band;
    final gold = Theme.of(context).colorScheme.primaryContainer;
    final tint = Color.lerp(teal, gold, (lift - 1).clamp(0.0, 1.0))!;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ColoredBox(
                color: tint.withValues(alpha: lift.clamp(0.0, 1.0)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "1 of 3" in a pill at the end of the band's title row.
class _CounterPill extends StatelessWidget {
  const _CounterPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.7),
        shape: const StadiumBorder(),
      ),
      child: Text(
        text,
        style: tabular(
          theme.textTheme.labelLarge!.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Dots for the cards checked and waiting, and how many follow the top one.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final after = total - done - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        if (total <= 12)
          ExcludeSemantics(
            child: Row(
              spacing: 4,
              children: [
                for (var i = 0; i < total; i++)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == done
                          ? scheme.onSurface
                          : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
        Text(
          after == 0 ? 'Last one' : '$after more after this',
          style: theme.textTheme.bodyMedium!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
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
