import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/database.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/theme/koban_theme.dart';
import 'package:koban/ui/payment_row.dart';
import 'package:material_ui/material_ui.dart';

final now = DateTime(2026, 11, 13, 12);

Expense expense({
  String id = 'a',
  String amount = '15.00',
  TransactionType type = TransactionType.withdraw,
  String? merchant = 'RESTORAN CONTOH',
  String? categoryId = 'food',
  String? counted,
  String? notes,
  ParseConfidence confidence = ParseConfidence.high,
  DateTime? at,
}) => Expense(
  id: id,
  amount: Decimal.parse(amount),
  currency: 'MYR',
  merchant: merchant,
  rawNotificationText: 'raw',
  sourcePackage: 'com.example',
  notificationPostTime: (at ?? now).millisecondsSinceEpoch,
  createdAt: 0,
  dedupKey: id,
  status: ExpenseStatus.autoSaved,
  confidence: confidence,
  categoryId: categoryId,
  notes: notes,
  transactionType: type,
  countedAmount: counted == null ? null : Decimal.parse(counted),
  privateToGroups: false,
);

Widget app(Widget body, {double textScale = 1}) => MaterialApp(
  theme: kobanTheme(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: body)),
);

Widget card(
  Expense e, {
  String? category = 'Food & Dining',
  bool confidence = false,
}) => ExpenseListCard(
  expense: e,
  categoryName: category,
  onEdit: () {},
  showConfidence: confidence,
);

void main() {
  testWidgets('a payment row shows the shop, time, category and amount', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var edits = 0;
    await tester.pumpWidget(
      app(
        ExpenseListCard(
          expense: expense(),
          categoryName: 'Food & Dining',
          onEdit: () => edits++,
        ),
      ),
    );
    expect(find.text('RESTORAN CONTOH'), findsOneWidget);
    expect(find.text('12:00 · Food & Dining'), findsOneWidget);
    expect(find.text('RM 15.00'), findsOneWidget);
    final node = tester.getSemantics(find.byType(ExpenseListCard));
    expect(node.hintOverrides?.onTapHint, 'Edit');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.text('RESTORAN CONTOH'));
    expect(edits, 1);

    // A text scale of 1.3 and a check tag cause no layout exception.
    await tester.pumpWidget(
      app(
        card(
          expense(notes: 'Lunch', confidence: ParseConfidence.low),
          confidence: true,
        ),
        textScale: 1.3,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Check amount'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a payment with no shop says Unknown shop', (tester) async {
    await tester.pumpWidget(app(card(expense(merchant: '  '))));
    expect(find.text('Unknown shop'), findsOneWidget);
  });

  testWidgets('a received payment has a plus sign', (tester) async {
    await tester.pumpWidget(
      app(card(expense(amount: '50.00', type: TransactionType.receive))),
    );
    expect(find.text('+ RM 50.00'), findsOneWidget);
  });

  testWidgets(
    'a used repayment says Repayment and a split spend says what was paid',
    (tester) async {
      await tester.pumpWidget(
        app(
          card(
            expense(
              amount: '50.00',
              type: TransactionType.receive,
              counted: '0.00',
            ),
          ),
        ),
      );
      expect(find.text('12:00 · Food & Dining\nRepayment'), findsOneWidget);
      expect(find.text('RM 50.00'), findsOneWidget);

      await tester.pumpWidget(
        app(
          card(
            expense(
              amount: '24.00',
              type: TransactionType.withdraw,
              counted: '10.00',
            ),
          ),
        ),
      );
      expect(find.text('12:00 · Food & Dining\npaid RM 24.00'), findsOneWidget);
      expect(find.text('RM 10.00'), findsOneWidget);
    },
  );

  testWidgets('the day header gives the spent total of the day', (
    tester,
  ) async {
    final widgets = expensesByDay(
      expenses: [
        expense(id: 'c', amount: '50.00', type: TransactionType.receive),
        expense(id: 'b', amount: '5.50'),
        expense(id: 'a', amount: '10.00'),
        expense(id: 'z', amount: '3.00', at: DateTime(2026, 11, 12, 9)),
      ],
      categoryName: (_) => 'Food & Dining',
      onEdit: (_) {},
      now: now,
    );
    expect(widgets, hasLength(2));
    await tester.pumpWidget(app(Column(children: widgets)));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('RM 15.50'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('RM 3.00'), findsNWidgets(2));
  });
}
