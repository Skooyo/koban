import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/summaries.dart';
import 'package:koban/theme/koban_theme.dart';
import 'package:koban/ui/category_donut.dart';
import 'package:material_ui/material_ui.dart';

CategoryBreakdown row(String? id, String name, String total) =>
    CategoryBreakdown(
      categoryId: id,
      name: name,
      colorHex: '#000000',
      total: Decimal.parse(total),
      fraction: 0,
    );

List<(String, Decimal, bool)> summary(List<DonutSlice> s) => [
  for (final e in s) (e.name, e.total, e.folded),
];

void main() {
  test('slices follow the fixed order and fold the rest', () {
    final s = donutSlices([
      row('bills', 'Bills', '10.00'),
      row('food', 'Food', '30.00'),
      row('c1', 'Pets', '5.00'),
      row(null, 'Uncategorized', '7.00'),
    ]);
    expect(summary(s), [
      ('Food', Decimal.parse('30'), false),
      ('Bills', Decimal.parse('10'), false),
      ('Everything else', Decimal.parse('12'), true),
    ]);
  });

  test('a single leftover keeps its name', () {
    final s = donutSlices([
      row(null, 'Uncategorized', '7.00'),
      row('food', 'Food', '30.00'),
    ]);
    expect(summary(s), [
      ('Food', Decimal.parse('30'), false),
      ('Uncategorized', Decimal.parse('7'), false),
    ]);
  });

  test('slices stop at 6 and fold the smallest built-in category', () {
    final s = donutSlices([
      row('food', 'Food', '60'),
      row('health', 'Health', '50'),
      row('transport', 'Transport', '40'),
      row('entertainment', 'Entertainment', '30'),
      row('shopping', 'Shopping', '20'),
      row('bills', 'Bills', '10'),
      row('other', 'Other', '5'),
    ]);
    expect(summary(s), [
      ('Food', Decimal.parse('60'), false),
      ('Health', Decimal.parse('50'), false),
      ('Transport', Decimal.parse('40'), false),
      ('Entertainment', Decimal.parse('30'), false),
      ('Shopping', Decimal.parse('20'), false),
      ('Everything else', Decimal.parse('15'), true),
    ]);
  });

  testWidgets('the donut tells the percent of each slice and its tap action', (
    tester,
  ) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: kobanTheme(Brightness.light),
        home: Center(
          child: CategoryDonut(
            slices: donutSlices([
              row('food', 'Food', '60'),
              row('bills', 'Bills', '40'),
            ]),
            onTap: () => taps++,
          ),
        ),
      ),
    );
    final node = tester.getSemantics(find.byType(CategoryDonut));
    expect(
      node.getSemanticsData().label,
      'Spending by category: Food 60 percent, Bills 40 percent',
    );
    expect(node.hintOverrides?.onTapHint, 'Filter by category');
    await tester.tap(find.byType(CategoryDonut));
    expect(taps, 1);
    handle.dispose();
  });
}
