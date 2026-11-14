import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../rules/amount_formatter.dart';
import '../../rules/types.dart';
import '../../theme/koban_theme.dart';
import '../../ui/amount_input.dart';
import '../../ui/date_labels.dart';
import '../../ui/dialogs.dart';
import '../../ui/kit.dart';
import '../payment/category_sheet.dart';
import 'check_payments_view_model.dart';

/// The time of [ms] in the phone's 12-hour or 24-hour format.
String _timeText(BuildContext context, int ms) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(ms)),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// One waiting payment. [stamp] gives the drag as -1 (full "Not a payment") to 1 (full "Save").
/// [onEdit] and [onChooseDirection] are null on the cards under the top one.
class CheckPaymentCard extends StatelessWidget {
  const CheckPaymentCard({
    super.key,
    required this.card,
    this.stamp,
    this.onEdit,
    this.onChooseDirection,
  });

  final CheckCard card;
  final ValueListenable<double>? stamp;
  final VoidCallback? onEdit;
  final ValueChanged<TransactionType>? onChooseDirection;

  @override
  Widget build(BuildContext context) {
    final payment = card.payment;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final money = MoneyColors.of(context);
    final muted = scheme.onSurfaceVariant;
    final received = payment.transactionType == TransactionType.receive;
    final timeText = _timeText(context, payment.notificationPostTime);
    final now = AppScope.of(context).now();
    final amountText =
        '${AmountFormatter.currencySymbol(payment.currency)} '
        '${AmountFormatter.formatGrouped(payment.amount)}';
    final amount = MoneyText(
      received ? '+ $amountText' : amountText,
      style: text.displayMedium,
      color: received ? money.received : scheme.onSurface,
    );
    final stamp = this.stamp;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: scheme.surfaceContainer,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      spacing: 8,
                      children: [
                        InitialsAvatar(card.appName, size: 32),
                        Flexible(
                          child: Text(
                            '${card.appName} · $timeText',
                            style: text.bodyMedium!.copyWith(color: muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (payment.format == CaptureFormat.unknown)
                          _Tag('Unknown format', money.review),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: onEdit == null
                        ? amount
                        : MergeSemantics(
                            child: Semantics(
                              button: true,
                              onTapHint: 'Change payment',
                              child: InkWell(
                                onTap: onEdit,
                                borderRadius: BorderRadius.circular(12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: amount,
                                ),
                              ),
                            ),
                          ),
                  ),
                  // Outside the amount, so each choice is its own button for screen readers.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DirectionSegments(
                      selected: payment.directionUnclear
                          ? null
                          : payment.transactionType,
                      onPick: payment.directionUnclear
                          ? onChooseDirection
                          : null,
                      onTapWhenFixed: onEdit,
                    ),
                  ),
                  if (payment.directionUnclear)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Spent or Received?',
                        style: text.bodyMedium!.copyWith(color: money.review),
                      ),
                    ),
                  ListGroup(
                    children: [
                      KobanRow(
                        title: payment.merchant ?? 'Not set',
                        subtitle: 'Shop',
                        showChevron: true,
                        onTap: onEdit,
                        onTapLabel: 'Change payment',
                      ),
                      KobanRow(
                        title: card.categoryName,
                        subtitle: 'Category',
                        leading: CategoryDot(
                          categoryColor(context, card.categoryId),
                          size: 12,
                        ),
                        showChevron: true,
                        onTap: onEdit,
                        onTapLabel: 'Change payment',
                      ),
                      KobanRow(
                        title:
                            '${dateLabel(payment.notificationPostTime, now)}, $timeText',
                        subtitle: 'Date',
                        showChevron: true,
                        onTap: onEdit,
                        onTapLabel: 'Change payment',
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '“${payment.rawNotificationText}”',
                        style: text.bodyMedium!.copyWith(color: muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The stamps only echo the drag. Screen readers get the card actions instead.
            if (stamp != null) ...[
              Positioned(
                top: 22,
                right: 18,
                child: _Stamp(
                  text: 'Save',
                  color: money.gold,
                  angle: 12,
                  alpha: stamp,
                  sign: 1,
                ),
              ),
              Positioned(
                top: 22,
                left: 18,
                child: _Stamp(
                  text: 'Not a payment',
                  color: money.red,
                  angle: -12,
                  alpha: stamp,
                  sign: -1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: ShapeDecoration(
      shape: const StadiumBorder(),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color),
    ),
  );
}

/// A stamp at an angle. It shows only while the drag goes in its direction ([sign]).
class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.text,
    required this.color,
    required this.angle,
    required this.alpha,
    required this.sign,
  });

  final String text;
  final Color color;
  final double angle;
  final ValueListenable<double> alpha;
  final double sign;

  @override
  Widget build(BuildContext context) {
    final stamp = ExcludeSemantics(
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: weighted(
              Theme.of(context).textTheme.titleLarge!,
              900,
            ).copyWith(color: color),
          ),
        ),
      ),
    );
    return ValueListenableBuilder<double>(
      valueListenable: alpha,
      child: stamp,
      builder: (context, v, child) {
        final a = (v * sign).clamp(0.0, 1.0);
        return a == 0
            ? const SizedBox.shrink()
            : Opacity(opacity: a, child: child);
      },
    );
  }
}

/// Opens [EditPaymentSheet] for [card]. A swipe down, Back or a tap outside
/// with changes asks "Discard changes?" first.
Future<void> showEditPaymentSheet(
  BuildContext context, {
  required CheckCard card,
  required List<Category> categories,
  required ValueChanged<PendingPayment> onSave,
}) {
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  return navigator.push(
    _EditSheetRoute(
      builder: (_) =>
          EditPaymentSheet(card: card, categories: categories, onSave: onSave),
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
    ),
  );
}

/// A bottom sheet route that stays open while [changed] is true, and asks first.
/// 0.1.1 does this with `confirmValueChange` of the sheet state.
class _EditSheetRoute extends ModalBottomSheetRoute<void> {
  _EditSheetRoute({
    required super.builder,
    required super.capturedThemes,
    required super.isScrollControlled,
    required super.useSafeArea,
    required super.showDragHandle,
    required super.barrierLabel,
    required super.barrierOnTapHint,
    required super.modalBarrierColor,
    required super.sheetAnimationStyle,
  });

  /// True while the sheet has changes. The sheet sets it.
  bool changed = false;
  bool _leaving = false;

  /// Closes the sheet without a question.
  void leave() {
    _leaving = true;
    if (isCurrent) navigator?.pop();
  }

  @override
  bool didPop(void result) {
    if (!changed || _leaving) return super.didPop(result);
    // A swipe down already started to close the sheet. Open it again.
    controller?.forward();
    // The navigator is busy during didPop. Ask after it.
    scheduleMicrotask(_ask);
    return false;
  }

  Future<void> _ask() async {
    final context = subtreeContext;
    if (context == null) return;
    if (await showDiscardChangesDialog(context)) leave();
  }
}

/// The add page's fields for one waiting card. A category is stored only when the owner picks one,
/// so an untouched card keeps following the shop memory.
class EditPaymentSheet extends StatefulWidget {
  const EditPaymentSheet({
    super.key,
    required this.card,
    required this.categories,
    required this.onSave,
  });

  final CheckCard card;
  final List<Category> categories;
  final ValueChanged<PendingPayment> onSave;

  @override
  State<EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends State<EditPaymentSheet> {
  PendingPayment get _payment => widget.card.payment;

  late String _amountText = AmountInput.fromAmount(_payment.amount);
  late TransactionType _type = _payment.transactionType;
  bool _typePicked = false;
  late String _merchant = _payment.merchant ?? '';
  late String? _categoryId = widget.card.categoryId;
  bool _categoryPicked = false;
  late int _time = _payment.notificationPostTime;

  bool get _changed =>
      _amountText != AmountInput.fromAmount(_payment.amount) ||
      _type != _payment.transactionType ||
      _merchant != (_payment.merchant ?? '') ||
      _categoryId != widget.card.categoryId ||
      _time != _payment.notificationPostTime;

  _EditSheetRoute? get _route => switch (ModalRoute.of(context)) {
    final _EditSheetRoute r => r,
    _ => null,
  };

  void _update(VoidCallback change) {
    setState(change);
    _route?.changed = _changed;
  }

  Future<void> _pickCategory() => showCategorySheet(
    context,
    categories: widget.categories,
    selectedId: _categoryId,
    onPick: (id) => _update(() {
      _categoryId = id;
      _categoryPicked = true;
    }),
  );

  Future<void> _pickDate() async {
    final picked = await showPastDatePicker(
      context,
      time: _time,
      now: AppScope.of(context).now(),
    );
    if (picked != null) _update(() => _time = picked);
  }

  void _save(Decimal amount) {
    final p = _payment;
    final merchant = _merchant.trim();
    final edited = p.copyWith(
      // 23.4 and 23.40 are the same money.
      amount: amount == p.amount ? p.amount : amount,
      transactionType: _type,
      // A tap on Spent or Received here is the owner's choice too.
      directionUnclear: p.directionUnclear && !_typePicked,
      merchant: Value(merchant.isEmpty ? null : merchant),
      categoryId: Value(_categoryPicked ? _categoryId : p.categoryId),
      notificationPostTime: _time,
    );
    if (edited != p) widget.onSave(edited);
    _route?.leave();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = AmountInput.toAmount(_amountText);
    final categoryName =
        widget.categories
            .where((c) => c.id == _categoryId)
            .map((c) => c.name)
            .firstOrNull ??
        CategoryRepository.uncategorizedName;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Semantics(
            header: true,
            child: Text('Change payment', style: theme.textTheme.titleLarge),
          ),
          DirectionSegments(
            selected: !_payment.directionUnclear || _typePicked ? _type : null,
            onPick: (t) => _update(() {
              _type = t;
              _typePicked = true;
            }),
          ),
          DialogTextField(
            value: _amountText,
            onChanged: (v) => _update(() => _amountText = v),
            label:
                'Amount (${AmountFormatter.currencySymbol(_payment.currency)})',
            isError: amount == null,
            supportingText: amount == null ? 'Type an amount above 0' : null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          DialogTextField(
            value: _merchant,
            onChanged: (v) => _update(() => _merchant = v),
            label: 'Shop',
            textCapitalization: TextCapitalization.words,
          ),
          ListGroup(
            children: [
              KobanRow(
                title: categoryName,
                subtitle: 'Category',
                leading: CategoryDot(
                  categoryColor(context, _categoryId),
                  size: 12,
                ),
                showChevron: true,
                onTap: _pickCategory,
                onTapLabel: 'Change category',
              ),
              KobanRow(
                title: dateLabel(_time, AppScope.of(context).now()),
                subtitle: 'Date',
                showChevron: true,
                onTap: _pickDate,
                onTapLabel: 'Change date',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: amount == null ? null : () => _save(amount),
                child: Text(
                  'Save changes',
                  style: weighted(theme.textTheme.titleMedium!, 700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
