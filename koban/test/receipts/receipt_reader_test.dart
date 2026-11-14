import 'package:flutter_test/flutter_test.dart';
import 'package:koban/receipts/receipt_reader.dart';
import 'package:koban/rules/receipt_rules.dart';

import '../support/harness.dart';

/// One printed row: a name on the left and a price on the right.
List<OcrLine> row(String name, String price, int top) => [
  OcrLine(name, 10, top, 200, top + 20),
  OcrLine(price, 300, top, 360, top + 20),
];

void main() {
  final t = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch;
  final lines = [
    OcrLine('Kedai Contoh', 100, 10, 260, 30),
    ...row('Nasi lemak', '20.00', 60),
    ...row('Teh ais', '4.00', 100),
    ...row('TOTAL', '24.00', 160),
  ];

  test('the reader gives the rules read of the OCR lines', () async {
    final reader = ReceiptReader(
      FakeReceiptOcr({'/cache/r.jpg': lines}),
      now: () => t,
    );

    final read = (await reader.read('/cache/r.jpg'))!;
    final expected = ReceiptRules.read(lines, now: t)!;

    expect(read.accepted, true);
    expect(read.accepted, expected.accepted);
    expect(read.draft.merchant, expected.draft.merchant);
    expect(read.draft.printedTotal, expected.draft.printedTotal);
    expect(
      read.draft.items.map((i) => (i.name, i.quantity, i.price)).toList(),
      expected.draft.items.map((i) => (i.name, i.quantity, i.price)).toList(),
    );
    expect(read.draft.items.map((i) => i.name), ['Nasi lemak', 'Teh ais']);
  });

  test('an OCR error gives null', () async {
    final reader = ReceiptReader(
      FakeReceiptOcr({'/cache/r.jpg': lines}, failing: {'/cache/r.jpg'}),
      now: () => t,
    );

    expect(await reader.read('/cache/r.jpg'), isNull);
  });
}
