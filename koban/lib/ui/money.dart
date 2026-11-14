import 'package:decimal/decimal.dart';
import 'package:material_ui/material_ui.dart';

import '../data/summaries.dart';
import '../rules/amount_formatter.dart';
import '../theme/koban_theme.dart';

/// "RM 12.50".
String rm(Decimal v) => 'RM ${AmountFormatter.formatGrouped(v)}';

/// Money with a small currency symbol. A negative [amount] means money received:
/// it shows as "+ RM" in the received color.
class MoneyAmount extends StatelessWidget {
  const MoneyAmount({
    super.key,
    required this.amount,
    required this.style,
    this.currency = 'MYR',
    this.color,
    this.symbolScale = 0.75,
  });

  final Decimal amount;
  final TextStyle style;
  final String currency;
  final Color? color;
  final double symbolScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final received = amount < Decimal.zero;
    return Text.rich(
      TextSpan(
        children: [
          if (received) const TextSpan(text: '+ '),
          TextSpan(
            text: '${AmountFormatter.currencySymbol(currency)} ',
            style: TextStyle(
              fontSize: (style.fontSize ?? 14) * symbolScale,
              color: scheme.onSurfaceVariant,
            ),
          ),
          TextSpan(text: AmountFormatter.formatGrouped(amount.abs())),
        ],
      ),
      style: tabular(style).copyWith(
        color: received
            ? MoneyColors.of(context).received
            : color ?? scheme.onSurface,
      ),
      maxLines: 1,
    );
  }
}

/// A solid fill for a category. Diagonal stripes for no category,
/// so it reads as "not sorted yet".
class CategoryFill extends StatelessWidget {
  const CategoryFill({
    super.key,
    required this.categoryId,
    required this.color,
  });

  final String? categoryId;
  final Color color;

  @override
  Widget build(BuildContext context) => categoryId != null
      ? ColoredBox(color: color, child: const SizedBox.expand())
      : CustomPaint(
          painter: _StripePainter(color),
          child: const SizedBox.expand(),
        );
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5;
    for (var x = -size.height; x < size.width; x += 5.5) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
    canvas.restore();
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.color != color;
}

/// Spending split by category, one banknote color per category.
/// Received money is left out.
class NoteStrip extends StatelessWidget {
  const NoteStrip({super.key, required this.breakdown, this.height = 14});

  final List<CategoryBreakdown> breakdown;
  final double height;

  @override
  Widget build(BuildContext context) {
    final spent = breakdown.where((b) => b.total > Decimal.zero).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: height,
        child: spent.isEmpty
            ? ColoredBox(
                color: Theme.of(context).colorScheme.outlineVariant,
                child: const SizedBox.expand(),
              )
            : Row(
                children: [
                  for (var i = 0; i < spent.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      // The flex is the total in cents. A tiny share still gets 1.
                      flex: (spent[i].total.toDouble() * 100).round().clamp(
                        1,
                        1 << 30,
                      ),
                      child: CategoryFill(
                        categoryId: spent[i].categoryId,
                        color: categoryColor(context, spent[i].categoryId),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// A thin bar that compares [total] with the largest total in a list.
class RelativeBar extends StatelessWidget {
  const RelativeBar({super.key, required this.total, this.max, this.color});

  final Decimal total;
  final Decimal? max;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = max;
    final fraction = m == null || m <= Decimal.zero || total <= Decimal.zero
        ? 0.0
        : (total / m)
              .toDecimal(scaleOnInfinitePrecision: 4)
              .round(scale: 4)
              .toDouble()
              .clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 4,
        color: scheme.outlineVariant,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction,
          heightFactor: 1,
          child: ColoredBox(color: color ?? scheme.primary),
        ),
      ),
    );
  }
}

/// Money received in a period. Totals count spending only, so this shows beside them.
class ReceivedNote extends StatelessWidget {
  const ReceivedNote(this.received, {super.key});

  final Decimal received;

  @override
  Widget build(BuildContext context) {
    if (received <= Decimal.zero) return const SizedBox.shrink();
    return Text(
      '+ ${rm(received)} received',
      style: Theme.of(context).textTheme.bodyMedium!
          .copyWith(color: MoneyColors.of(context).received),
    );
  }
}
