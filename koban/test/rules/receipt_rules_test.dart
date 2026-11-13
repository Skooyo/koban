import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/receipt_rules.dart';

/// Largest Kotlin Long. Used as "now" so that no date is in the future.
const int _farFuture = 9223372036854775807;

Decimal _d(String s) => Decimal.parse(s);

List<OcrLine> _row(int y, List<(int, String)> parts) => [
  for (final (x, text) in parts) OcrLine(text, x, y, x + 100, y + 20),
];

List<ReceiptItemDraft> _items(List<String> rows) =>
    ReceiptRules.parse(rows).items;

ReceiptItemDraft _item(String name, int qty, String price) =>
    ReceiptItemDraft(name, qty, _d(price));

List<OcrLine> _lines(List<String> rows) => [
  for (var i = 0; i < rows.length; i++) ..._row(i * 40, [(10, rows[i])]),
];

ReceiptRead _read(List<String> rows, {int now = _farFuture}) =>
    ReceiptRules.read(_lines(rows), now: now)!;

int _midnight(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch;

void main() {
  test('name and price lines join into one row', () {
    final lines = [
      ..._row(100, [(10, 'NASI LEMAK')]),
      ..._row(102, [(300, '8.50')]),
    ];
    expect(ReceiptRules.rows(lines), ['NASI LEMAK 8.50']);
  });

  test('amount repair', () {
    expect(
      ReceiptRules.fixRow('TEH TARIK 2 x 2.50 5 00'),
      'TEH TARIK 2 x 2.50 5.00',
    );
    expect(ReceiptRules.fixRow('SUBTOTAL. 79, 60'), 'SUBTOTAL. 79.60');
    expect(
      ReceiptRules.fixRow('Rounding Adj : -0. 03'),
      'Rounding Adj : -0.03',
    );
    expect(ReceiptRules.fixRow('ROTI 1O.50'), 'ROTI 10.50');
  });

  test('thousands separator kept', () {
    expect(ReceiptRules.fixRow('TOTAL 1,234.00'), 'TOTAL 1,234.00');
  });

  test('time row is not an item', () {
    expect(_items(['Time: 12:06 00', 'MEE GORENG 7.00', 'TOTAL 7.00']), [
      _item('MEE GORENG', 1, '7.00'),
    ]);
  });

  test('fuzzy labels', () {
    expect(ReceiptRules.normLabel('SULTOTAL.'), contains('SUBTOTAL'));
    expect(ReceiptRules.normLabel('Total Amnolunt :'), contains('AMOUNT'));
    expect(ReceiptRules.normLabel('NLI T0TAL'), contains('TOTAL'));
  });

  test('item name near keyword stays item', () {
    expect(_items(['PHONE CASE 10.00', 'EXCHANGE TEA 3.00', 'TOTAL 13.00']), [
      _item('PHONE CASE', 1, '10.00'),
      _item('EXCHANGE TEA', 1, '3.00'),
    ]);
  });

  test('restaurant bill', () {
    final p = ReceiptRules.parse([
      'TEH O AIS',
      '1X 2.50 2.50 SR',
      'NASI AYAM',
      '2X 9.00 18.00 SR',
      'TOTAL (EXCLUDING SST): 20.50',
      'SERV. CHARGE(10%): 2.05',
      'SST PAYABLE: 1.35',
      'TOTAL (INCLUSIVE OF SST): 23.90',
      'ROUNDING ADJ: 0.00',
      'TOTAL: 23.90',
      'CASH : 50.00',
      'CHANGE : 26.10',
    ]);
    expect(p.items, [
      _item('TEH O AIS', 1, '2.50'),
      _item('NASI AYAM', 2, '18.00'),
    ]);
    expect(p.subtotal, _d('20.50'));
    expect(p.serviceCharge, _d('2.05'));
    expect(p.tax, _d('1.35'));
    expect(p.rounding, _d('0.00'));
    expect(p.totals, [_d('23.90'), _d('23.90')]);
  });

  test('tilted scan pairs each price with the name below', () {
    final p = ReceiptRules.parse([
      'Qty Description Total TAX',
      '1 0 40.00 SR',
      'Fish Noodle',
      'D 12.00 SR',
      'Green Tea',
      '1 D 6.50 SR',
      'Plain Rice',
      '1 D 3.00 SR',
      'Soda',
      'Total (Excluding GST): 61.50',
      'Total: 61.50',
    ]);
    expect(p.items, [
      _item('Fish Noodle', 1, '40.00'),
      _item('Green Tea', 1, '12.00'),
      _item('Plain Rice', 1, '6.50'),
      _item('Soda', 1, '3.00'),
    ]);
  });

  test('tilted photo keeps each price on its item row', () {
    // ML Kit output of one made-up receipt photographed at -1.2 and +4 degrees: each price is its own line.
    for (final lines in [tiltMinus12, tiltPlus4]) {
      final read = ReceiptRules.read(lines, now: _farFuture)!;
      expect(read.draft.items, [
        _item('Nasi Lemak Ayam', 1, '14.90'),
        _item('Mee Goreng Mamak', 1, '12.50'),
        _item('Roti Canai', 2, '5.00'),
        _item('Teh Tarik', 3, '9.00'),
        _item('Milo Ais', 1, '4.50'),
      ]);
      expect(read.draft.serviceCharge, _d('4.59'));
      expect(read.draft.tax, _d('3.03'));
      expect(read.draft.rounding, _d('-0.02'));
      expect(read.accepted, true);
    }
  });

  test('tax codes and dollar', () {
    final p = ReceiptRules.parse([
      'COKE',
      '1 X 2.10 2.10 ZRL',
      'MEAT + VEGE',
      r'1 $7.10',
      r'$7.10',
      r'NETT TOTAL: $9.20',
    ]);
    expect(p.items, [
      _item('COKE', 1, '2.10'),
      _item('MEAT + VEGE', 1, '7.10'),
    ]);
    expect(p.totals, [_d('9.20')]);
  });

  test('nameless items', () {
    expect(_items(['4 3.50 14.00 SR-', '1 3.00 3.00 SR-', 'TOTAL: 17.00']), [
      _item('Item', 4, '14.00'),
      _item('Item', 1, '3.00'),
    ]);
  });

  test('stops at summary', () {
    expect(
      _items([
        'TEA 3.00',
        'GST SUMMARY AMOUNT(RM) TAX(RM)',
        'COFFEE 4.00',
        'TOTAL 7.00',
      ]),
      [_item('TEA', 1, '3.00')],
    );
  });

  test('reading 1: prices include everything', () {
    final r = _read([
      'ROTI 10.00',
      'TEH 5.00',
      'SST 6% INCLUDED 0.85',
      'TOTAL 15.00',
    ]);
    expect(r.accepted, true);
    expect(r.draft.tax, _d('0.00'));
    expect(r.draft.serviceCharge, _d('0.00'));
    expect(r.calculated, <String>[]);
  });

  test('reading 4: charges added', () {
    final r = _read([
      'TEH O AIS',
      '1X 2.50 2.50 SR',
      'NASI AYAM',
      '2X 9.00 18.00 SR',
      'TOTAL (EXCLUDING SST): 20.50',
      'SERV. CHARGE(10%): 2.05',
      'SST PAYABLE: 1.35',
      'TOTAL (INCLUSIVE OF SST): 23.90',
      'ROUNDING ADJ: 0.00',
      'TOTAL: 23.90',
      'CASH : 50.00',
      'CHANGE : 26.10',
    ]);
    expect(r.accepted, true);
    expect(r.draft.serviceCharge, _d('2.05'));
    expect(r.draft.tax, _d('1.35'));
    expect(r.draft.printedTotal, _d('23.90'));
    expect(r.calculated, <String>[]);
  });

  test('reading 5: tax already in prices', () {
    final r = _read([
      'MEE 20.00',
      'SERVICE CHARGE 2.00',
      'SST 6% 1.25',
      'TOTAL 22.00',
    ]);
    expect(r.accepted, true);
    expect(r.draft.tax, _d('0.00'));
    expect(r.draft.serviceCharge, _d('2.00'));
  });

  test('reading 6: missing service charge calculated', () {
    final r = _read([
      'SET A 79.60',
      'DISCOUNT 30.00',
      'ROUNDING -0.03',
      'TOTAL 57.80',
    ]);
    expect(r.accepted, true);
    expect(r.draft.serviceCharge, _d('4.96'));
    expect(r.draft.tax, _d('3.27'));
    expect(r.calculated, ['10% service charge', '6% SST']);
  });

  test('five sen rounding', () {
    final r = _read(['KUIH 7.72', 'TOTAL 7.70']);
    expect(r.accepted, true);
    expect(r.draft.rounding, _d('-0.02'));
  });

  test('near match puts cent in rounding', () {
    final r = _read(['ROTI 10.00', 'TEH 13.90', 'TOTAL 23.89']);
    expect(r.accepted, true);
    expect(r.draft.rounding, _d('-0.01'));
    final d = r.draft;
    final sum =
        d.items.fold(Decimal.zero, (a, i) => a + i.price) +
        d.serviceCharge +
        d.tax -
        d.discount +
        d.rounding;
    expect(sum.compareTo(d.printedTotal!), 0);
  });

  test('subtotal never accepts', () {
    final r = _read(['BARANG 295.00', 'SUB TOTAL 295.00', 'TOTAL 350.00']);
    expect(r.accepted, false);
    expect(r.draft.printedTotal, _d('350.00'));
  });

  test('last total wins', () {
    final r = _read([
      'MEE 20.00',
      'TOTAL 20.00',
      'SERVICE CHARGE 2.00',
      'TOTAL 22.00',
    ]);
    expect(r.accepted, true);
    expect(r.draft.printedTotal, _d('22.00'));
    expect(r.draft.serviceCharge, _d('2.00'));
  });

  test('no total not accepted', () {
    final r = _read(['MEE 20.00']);
    expect(r.accepted, false);
    expect(r.draft.printedTotal, isNull);
  });

  test('empty OCR gives null', () {
    expect(ReceiptRules.read([]), isNull);
    expect(ReceiptRules.read(_lines(['THANK YOU'])), isNull);
  });

  test('zero amounts ignored', () {
    final r = _read([
      'NASI 12.00',
      'FREE SAMBAL 0.00',
      'DISCOUNT 0.00',
      'TOTAL 12.00',
    ]);
    expect(r.accepted, true);
    expect(r.draft.items.length, 1);
  });

  test('merchant and date', () {
    final top = [
      'KEDAI MAKAN CONTOH',
      'SDN BHD (123456-X)',
      'NO. 1 JALAN CONTOH',
      'TEL: 03-1234 5678',
      'DATE: 05/10/2026 13:05',
      'MEE 5.00',
      'TOTAL 5.00',
    ];
    final now = _midnight(2026, 11, 2);
    final r = _read(top, now: now);
    expect(r.draft.merchant, 'KEDAI MAKAN CONTOH');
    expect(r.draft.dateMillis, _midnight(2026, 10, 5));
    expect(
      _read([
        'MEE 5.00',
        'DATE: 31/02/2026',
        'TOTAL 5.00',
      ], now: now).draft.dateMillis,
      isNull,
    );
    expect(
      _read([
        'MEE 5.00',
        'DATE: 03/11/2026',
        'TOTAL 5.00',
      ], now: now).draft.dateMillis,
      isNull,
    );
    expect(
      _read([
        'MEE 5.00',
        '5 Oct 2026',
        'TOTAL 5.00',
      ], now: now).draft.dateMillis,
      _midnight(2026, 10, 5),
    );
    expect(
      _read([
        'MEE 5.00',
        '2026-10-05',
        'TOTAL 5.00',
      ], now: now).draft.dateMillis,
      _midnight(2026, 10, 5),
    );
  });

  test('amount of thousands without comma keeps all digits', () {
    expect(ReceiptRules.parse(['TOTAL 1234.00']).totals, [_d('1234.00')]);
    expect(ReceiptRules.parse(['TOTAL 1,234.00']).totals, [_d('1234.00')]);
  });

  test('big item without comma is accepted', () {
    final r = _read(['BANQUET SET 1250.00', 'TOTAL RM1250.00']);
    expect(r.accepted, true);
    expect(r.draft.items, [_item('BANQUET SET', 1, '1250.00')]);
    expect(r.draft.printedTotal, _d('1250.00'));
  });

  test('discount keyword inside item name is an item', () {
    expect(_items(['TEH LESS SUGAR 3.00', 'SET PROMO A 9.00', 'TOTAL 12.00']), [
      _item('TEH LESS SUGAR', 1, '3.00'),
      _item('SET PROMO A', 1, '9.00'),
    ]);
    final p = ReceiptRules.parse([
      'ROTI 5.00',
      'DISCOUNT 1.00',
      'PROMO -0.50',
      'TOTAL 3.50',
    ]);
    expect(p.discount, _d('1.50'));
  });
}

final tiltMinus12 = <OcrLine>[
  OcrLine('RESTORAN SERI MELATI', 327, 494, 730, 526, angle: -1.15),
  OcrLine('No. 12, Jalan Melati 3', 360, 539, 699, 569, angle: -1.19),
  OcrLine('47500 Subang Jaya, Selangor', 324, 578, 740, 607, angle: -0.84),
  OcrLine('Tel: 03-5600 1234', 402, 617, 661, 642, angle: -1.17),
  OcrLine('Table 7', 226, 700, 329, 719, angle: -1.38),
  OcrLine('Bill #004512', 227, 735, 408, 758, angle: -1.17),
  OcrLine('1 Nasi Lemak Ayam', 230, 811, 491, 835, angle: -0.85),
  OcrLine('1 Mee Goreng Mamak', 231, 847, 507, 873, angle: -1.04),
  OcrLine('2 Roti Canai', 230, 883, 411, 911, angle: -1.75),
  OcrLine('3 Teh Tarik', 232, 926, 397, 946, angle: -0.69),
  OcrLine('1 Milo Ais', 233, 961, 382, 983, angle: -0.79),
  OcrLine('Subtotal', 234, 1039, 351, 1059, angle: -1.09),
  OcrLine('Service Charge 10%', 235, 1073, 509, 1098, angle: -0.78),
  OcrLine('SST 6%', 235, 1116, 322, 1136, angle: -1.59),
  OcrLine('Rounding', 235, 1154, 358, 1175, angle: 0.0),
  OcrLine('TOTAL', 237, 1232, 335, 1256, angle: -0.69),
  OcrLine('Visa Debit', 237, 1275, 389, 1298, angle: -1.24),
  OcrLine('18/10/2026 20: 09', 598, 687, 841, 713, angle: -1.09),
  OcrLine('Terima kasih!', 449, 1346, 642, 1371, angle: -1.4),
  OcrLine('Pax: 3', 754, 726, 841, 749, angle: -2.82),
  OcrLine('14.90', 772, 802, 842, 823, angle: -1.88),
  OcrLine('Thank you, please come again', 332, 1383, 764, 1414, angle: -1.23),
  OcrLine('12.50', 773, 841, 845, 859, angle: 0.0),
  OcrLine('5.00', 789, 879, 846, 897, angle: 0.0),
  OcrLine('9.00', 790, 917, 847, 935, angle: 0.0),
  OcrLine('4.50', 791, 954, 848, 972, angle: 0.0),
  OcrLine('45.90', 776, 1029, 848, 1048, angle: -0.77),
  OcrLine('4.59', 793, 1068, 850, 1086, angle: 0.0),
  OcrLine('3.03', 794, 1106, 851, 1124, angle: 0.0),
  OcrLine('-0.02', 779, 1143, 852, 1161, angle: 0.0),
  OcrLine('RM 53.50', 693, 1220, 851, 1248, angle: -1.48),
  OcrLine('53.50', 781, 1266, 852, 1286, angle: -1.1),
];

final tiltPlus4 = <OcrLine>[
  OcrLine('Table 7', 249, 675, 355, 698, angle: 3.25),
  OcrLine('Bill #004512', 246, 712, 429, 742, angle: 3.56),
  OcrLine('1 Nasi Lemak Ayam', 242, 787, 506, 829, angle: 4.46),
  OcrLine('1 Mee Goreng Mamak', 240, 825, 515, 865, angle: 3.92),
  OcrLine('RESTORAN SERI MELATI', 367, 486, 773, 536, angle: 3.86),
  OcrLine('No. 12, Jalan Melati 3', 397, 534, 737, 577, angle: 3.76),
  OcrLine('47500 Subang Jaya, Selangor', 357, 567, 775, 620, angle: 4.09),
  OcrLine('Tel: 03-5600 1234', 431, 612, 691, 647, angle: 3.86),
  OcrLine('2 Roti Canai', 236, 863, 416, 893, angle: 4.03),
  OcrLine('3 Teh Tarik', 234, 900, 402, 931, angle: 4.19),
  OcrLine('Subtotal', 226, 1013, 347, 1040, angle: 4.22),
  OcrLine('1 Milo Ais', 232, 937, 382, 965, angle: 3.6),
  OcrLine('SST 6%', 220, 1090, 310, 1113, angle: 3.54),
  OcrLine('Service Charge 10%', 223, 1052, 500, 1090, angle: 3.92),
  OcrLine('Rounding', 217, 1126, 340, 1157, angle: 4.42),
  OcrLine('TOTAL', 211, 1206, 312, 1233, angle: 3.53),
  OcrLine('Visa Debit', 207, 1253, 361, 1279, angle: 3.89),
  OcrLine('Terima kasih!', 411, 1341, 606, 1372, angle: 3.99),
  OcrLine('18/10/2026 20:09', 620, 700, 864, 736, angle: 3.96),
  OcrLine('Pax: 3', 773, 750, 862, 772, angle: 2.1),
  OcrLine('Thank you, please come again', 292, 1372, 726, 1423, angle: 3.95),
  OcrLine('14.90', 783, 825, 857, 849, angle: 4.55),
  OcrLine('12.50', 780, 863, 854, 885, angle: 3.27),
  OcrLine('5.00', 793, 903, 851, 922, angle: 0.92),
  OcrLine('9.00', 792, 942, 849, 962, angle: 0.0),
  OcrLine('4.50', 789, 979, 846, 999, angle: 0.0),
  OcrLine('45.90', 766, 1051, 841, 1073, angle: 3.43),
  OcrLine('4.59', 781, 1093, 839, 1112, angle: 0.0),
  OcrLine('3.03', 778, 1130, 836, 1150, angle: 0.0),
  OcrLine('-0.02', 757, 1164, 833, 1186, angle: 3.39),
  OcrLine('RM 53.50', 666, 1238, 827, 1271, angle: 2.99),
  OcrLine('53.50', 751, 1289, 824, 1311, angle: 2.24),
];
