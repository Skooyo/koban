import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:material_ui/material_ui.dart';

import '../../app/app_services.dart';
import '../../data/database.dart';
import '../../rules/amount_formatter.dart';
import '../../rules/top_up.dart';
import '../../rules/types.dart';
import '../../theme/koban_theme.dart';
import '../../ui/amount_input.dart';
import '../../ui/category_chips.dart';
import '../../ui/date_labels.dart';
import '../../ui/dialogs.dart';
import '../../ui/kit.dart';
import 'check_payments_view_model.dart';

/// The time of [ms] in the phone's 12-hour or 24-hour format.
String _timeText(BuildContext context, int ms) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(ms)),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

const _fieldShape = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide.none,
);

/// The waiting payment on one flat card. Amount, shop, category, date and
/// Spent or Received are edited on the card. Text edits go to the database
/// when a field loses focus and when [CheckPaymentCardState.flush] runs.
class CheckPaymentCard extends StatefulWidget {
  const CheckPaymentCard({
    super.key,
    required this.card,
    required this.categories,
    required this.mostUsedIds,
    required this.onEdit,
    required this.onMoreCategories,
  });

  final CheckCard card;
  final List<Category> categories;
  final List<String> mostUsedIds;
  final Future<void> Function(PendingPayment edited) onEdit;
  final VoidCallback onMoreCategories;

  @override
  State<CheckPaymentCard> createState() => CheckPaymentCardState();
}

class CheckPaymentCardState extends State<CheckPaymentCard> {
  PendingPayment get _payment => widget.card.payment;

  late final _amount = TextEditingController(
    text: AmountInput.fromAmount(_payment.amount),
  );
  late final _shop = TextEditingController(text: _payment.merchant ?? '');

  @override
  void dispose() {
    // Back or a closed screen with a field still focused: keep the typed text.
    unawaited(flush());
    _amount.dispose();
    _shop.dispose();
    super.dispose();
  }

  /// Writes the typed amount and shop. False when the amount is not above 0;
  /// the field shows the error then.
  Future<bool> flush() async {
    final amount = AmountInput.toAmount(_amount.text);
    if (amount == null) return false;
    final p = _payment;
    final shop = _shop.text.trim();
    final edited = p.copyWith(
      // 23.4 and 23.40 are the same money.
      amount: amount == p.amount ? p.amount : amount,
      merchant: Value(shop.isEmpty ? null : shop),
    );
    if (edited != p) await widget.onEdit(edited);
    return true;
  }

  Future<void> _pickDate() async {
    final picked = await showPastDatePicker(
      context,
      time: _payment.notificationPostTime,
      now: AppScope.of(context).now(),
    );
    if (picked != null && picked != _payment.notificationPostTime) {
      await widget.onEdit(_payment.copyWith(notificationPostTime: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final payment = card.payment;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final money = MoneyColors.of(context);
    final muted = scheme.onSurfaceVariant;
    final received = payment.transactionType == TransactionType.receive;
    final now = AppScope.of(context).now();
    final topUp = looksLikeTopUp(payment.rawNotificationText);
    final guessed = payment.format == CaptureFormat.unknown && !topUp;
    final dateText =
        '${dateLabel(payment.notificationPostTime, now)}, '
        '${_timeText(context, payment.notificationPostTime)}';
    final symbol = AmountFormatter.currencySymbol(payment.currency);
    final amountBad = AmountInput.toAmount(_amount.text) == null;

    InputDecoration field(
      String label, {
      String? prefix,
      String? error,
    }) => InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: text.bodyMedium!.copyWith(color: muted),
      prefixText: prefix,
      errorText: error,
      // The pencil says the row can be typed in. Screen readers get the label.
      suffixIcon: ExcludeSemantics(
        child: Icon(Icons.edit_outlined, size: 18, color: muted),
      ),
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: _fieldShape,
      enabledBorder: _fieldShape,
      focusedBorder: _fieldShape,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      constraints: const BoxConstraints(minHeight: 48),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 6,
            children: [
              Icon(Icons.notifications_none, size: 16, color: muted),
              Text(
                'From ${card.appName}',
                style: weighted(text.bodyMedium!, 700),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  onTapHint: 'Change date',
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: 6,
                        children: [
                          Flexible(
                            child: Text(
                              dateText,
                              style: tabular(
                                text.bodyMedium!.copyWith(color: muted),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ExcludeSemantics(
                            child: Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Each choice is its own button for screen readers. A tap switches
          // Spent or Received, also when the direction is known.
          DirectionSegments(
            selected: payment.directionUnclear ? null : payment.transactionType,
            onPick: (type) => widget.onEdit(
              payment.copyWith(transactionType: type, directionUnclear: false),
            ),
          ),
          if (payment.directionUnclear)
            Text(
              'Spent or Received?',
              style: text.bodyMedium!.copyWith(color: money.review),
            ),
          Focus(
            onFocusChange: (focused) {
              if (!focused) flush();
            },
            child: TextField(
              controller: _amount,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              inputFormatters: [AmountInput.formatter],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              style: tabular(
                text.headlineLarge!.copyWith(
                  color: received ? money.received : scheme.onSurface,
                ),
              ),
              cursorColor: scheme.primary,
              decoration: field(
                'Amount',
                prefix: received ? '+ $symbol ' : '$symbol ',
                error: amountBad ? 'Type an amount above 0' : null,
              ),
            ),
          ),
          Focus(
            onFocusChange: (focused) {
              if (!focused) flush();
            },
            child: TextField(
              controller: _shop,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: text.titleMedium!.copyWith(color: scheme.onSurface),
              cursorColor: scheme.primary,
              decoration: field('Shop'),
            ),
          ),
          if (guessed)
            Text(
              'Shop · guessed',
              style: text.bodySmall!.copyWith(color: money.review),
            ),
          CategoryChips(
            chips: chipCategoriesFor(
              widget.categories,
              widget.mostUsedIds,
              card.categoryId,
            ),
            selectedId: card.categoryId,
            onPick: (id) =>
                widget.onEdit(payment.copyWith(categoryId: Value(id))),
            onMore: widget.onMoreCategories,
            padding: EdgeInsets.zero,
          ),
          if (topUp)
            _Note(
              icon: Icons.swap_horiz,
              color: scheme.primary,
              text: 'Looks like a wallet top-up, so usually not a payment.',
            )
          else if (guessed)
            _Note(
              icon: Icons.help_outline,
              color: money.review,
              text:
                  'Koban did not know this message, so it guessed the shop '
                  'and Spent or Received. Check them before you save.',
            ),
          _RawText('“${payment.rawNotificationText}”'),
        ],
      ),
    );
  }
}

/// A short note on the card with an icon in [color].
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        Icon(icon, size: 20, color: color),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

/// The notification text in one line, with "Show full text" when it is longer.
class _RawText extends StatefulWidget {
  const _RawText(this.text);

  final String text;

  @override
  State<_RawText> createState() => _RawTextState();
}

class _RawTextState extends State<_RawText> {
  static const _pad = 12.0;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: box.maxWidth - 2 * _pad);
        final long = painter.didExceedMaxLines;
        painter.dispose();
        final folded = long && !_open;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: _pad,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.text,
                style: style,
                maxLines: folded ? 1 : null,
                overflow: folded ? TextOverflow.ellipsis : null,
              ),
            ),
            if (long)
              TextButton(
                onPressed: () => setState(() => _open = !_open),
                child: Text(_open ? 'Show less' : 'Show full text'),
              ),
          ],
        );
      },
    );
  }
}
