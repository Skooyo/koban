import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import '../rules/amount_formatter.dart';
import '../rules/types.dart';
import '../theme/koban_theme.dart';
import 'date_labels.dart';
import 'kit.dart';
import 'money.dart';

Decimal _effective(Expense e) => e.countedAmount ?? e.amount;

/// One transaction as a row for a [ListGroup]. A tap on the row edits it.
class ExpenseListCard extends StatelessWidget {
  const ExpenseListCard({
    super.key,
    required this.expense,
    required this.categoryName,
    required this.onEdit,
    this.showConfidence = false,
    this.timePattern = 'HH:mm',
  });

  final Expense expense;
  final String? categoryName;
  final VoidCallback onEdit;
  final bool showConfidence;
  final String timePattern;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat(
      timePattern,
      'en_US',
    ).format(DateTime.fromMillisecondsSinceEpoch(e.notificationPostTime));
    final merchant = e.merchant != null && e.merchant!.trim().isNotEmpty
        ? e.merchant!
        : 'Unknown shop';
    final counted = e.countedAmount;
    final isRepayment =
        e.transactionType == TransactionType.receive && counted == Decimal.zero;
    final partlyCounted =
        e.transactionType == TransactionType.withdraw &&
        counted != null &&
        counted != e.amount;
    final signed = isRepayment
        ? e.amount
        : e.transactionType == TransactionType.receive
        ? -e.amount
        : _effective(e);
    final info = [
      [time, ?categoryName].join(' · '),
      if (isRepayment)
        'Repayment'
      else if (partlyCounted)
        'paid ${AmountFormatter.currencySymbol(e.currency)} ${AmountFormatter.formatGrouped(e.amount)}',
    ];
    final notes = e.notes != null && e.notes!.trim().isNotEmpty
        ? e.notes!
        : null;
    final subtitle = [...info, ?notes].join('\n');

    return KobanRow(
      title: merchant,
      subtitle: subtitle,
      leading: CategoryBadge(e.categoryId),
      trailing: MoneyAmount(
        amount: signed,
        currency: e.currency,
        style: weighted(Theme.of(context).textTheme.titleMedium!, 700),
        color: isRepayment ? scheme.onSurfaceVariant : scheme.onSurface,
      ),
      titleSuffix: showConfidence && e.confidence != ParseConfidence.high
          ? _CheckBadge(
              e.confidence == ParseConfidence.low
                  ? 'Check amount'
                  : 'Check shop',
            )
          : null,
      onTap: onEdit,
      onTapLabel: 'Edit',
      // The info lines always show. The notes get at most 2 lines.
      subtitleMaxLines: info.length + 2,
    );
  }
}

/// A small "Check" tag for a payment whose amount or shop the parser was unsure about.
class _CheckBadge extends StatelessWidget {
  const _CheckBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final review = MoneyColors.of(context).review;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: review),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: review),
      ),
    );
  }
}

/// The transactions under one heading per day, each day in one [ListGroup].
/// [expenses] must be sorted newest first.
List<Widget> expensesByDay({
  required List<Expense> expenses,
  required String? Function(Expense) categoryName,
  required void Function(Expense) onEdit,
  required DateTime now,
}) {
  final days = <String, List<Expense>>{};
  final dayKey = DateFormat('yyyyMMdd', 'en_US');
  for (final e in expenses) {
    final key = dayKey.format(
      DateTime.fromMillisecondsSinceEpoch(e.notificationPostTime),
    );
    days.putIfAbsent(key, () => []).add(e);
  }
  return [
    for (final MapEntry(:key, value: dayExpenses) in days.entries)
      Padding(
        key: ValueKey('day-$key'),
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DayHeader(expenses: dayExpenses, now: now),
            ListGroup(
              children: [
                for (final e in dayExpenses)
                  ExpenseListCard(
                    key: ValueKey(e.id),
                    expense: e,
                    categoryName: categoryName(e),
                    onEdit: () => onEdit(e),
                    showConfidence: true,
                  ),
              ],
            ),
          ],
        ),
      ),
  ];
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.expenses, required this.now});

  final List<Expense> expenses;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final spent = expenses.fold(
      Decimal.zero,
      (sum, e) => e.transactionType == TransactionType.receive
          ? sum
          : sum + _effective(e),
    );
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: SectionHeading(
              dayHeaderLabel(expenses.first.notificationPostTime, now),
            ),
          ),
          MoneyAmount(
            amount: spent,
            style: theme.textTheme.labelLarge!,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
