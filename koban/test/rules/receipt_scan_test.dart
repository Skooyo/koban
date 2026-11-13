import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/amount_formatter.dart';
import 'package:koban/rules/receipt_cloud.dart';
import 'package:koban/rules/receipt_rules.dart';

/// Largest Kotlin Long. Used as "now" so that no date is in the future.
const int _farFuture = 9223372036854775807;

Decimal _d(String s) => Decimal.parse(s);

// A real phone scan (document scanner, 2026-11-12) tilted by about -3 degrees:
// every price sits about 60 px above its item name. Shop name, address, phone
// and email are changed.
//
// A real phone scan of a level but slightly curled receipt: prices sit level
// with their names, yet ML Kit reports +0.6 to +1.3 degrees on some wide
// lines. Straightening this scan shifts every price one item down, so the
// plain read must win. OCR misread "3.00" as "300," and the SST as "7.63", so
// the read is not accepted. Shop name, address, phone and invoice number are
// changed.

const String _reply = '''{"merchant":"Ramen Shop","date":"2026-11-07",
        "items":[{"name":"Kimista (Large)","quantity":1,"price":"26.00"},{"name":"Ajitama","quantity":2,"price":"6.00"}],
        "serviceCharge":"0.00","tax":"2.28","discount":"0.00","rounding":"0.02","total":"34.30","readsLeftToday":7}''';

ReceiptRead _rulesRead(bool accepted) => ReceiptRead(
  ReceiptDraft(
    merchant: null,
    dateMillis: null,
    items: [ReceiptItemDraft('Ramen', 1, _d('34.30'))],
    serviceCharge: Decimal.zero,
    tax: Decimal.zero,
    discount: Decimal.zero,
    rounding: Decimal.zero,
    printedTotal: _d('34.30'),
  ),
  accepted,
  const [],
);

String _plain(Decimal v) => AmountFormatter.formatDisplay(v);

// The Kotlin test is skipped when the git-ignored receipt-bench folder is
// missing. The Dart test runs from the koban folder, so the folder is one level up.
final Directory _benchRoot = Directory('../receipt-bench');
final bool _hasBench = Directory('${_benchRoot.path}/mlkit').existsSync();

final RegExp _food = RegExp(
  'RESTORAN|RESTAURANT|CAFE|KOPITIAM|FOOD|NASI|MAKAN|BAKERY|KITCHEN|SEAFOOD|BISTRO|DIM SUM|'
  'BAK KUT|CHICKEN|BURGER|PIZZA|SUSHI|MAMAK|CATERING|DELIGHTS|STOOGES|PUB|DAKGALBI|COFFEE|'
  'TEALIVE|MENTAI|WARAKUYA|UNIHAKKA|KITCHENETTE|SUNFISH|BANH MI',
  caseSensitive: false,
);

class _Stats {
  int n = 0, accepted = 0, correct = 0, wrong = 0;
  int merchantN = 0, merchantOk = 0, dateN = 0, dateOk = 0;
  final List<String> correctIds = [];
  final List<String> wrongIds = [];

  String _pct(int x, int d) =>
      d == 0 ? 'n/a' : '${(100.0 * x / d).toStringAsFixed(1)}%';

  String report(String name) =>
      'Benchmark $name n=$n accepted-correct ${_pct(correct, n)} flagged ${_pct(n - accepted, n)} '
      'wrong-not-flagged $wrong merchant ${_pct(merchantOk, merchantN)} date ${_pct(dateOk, dateN)}';
}

String _norm(String s) =>
    s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Day, month, year from a SROIE date string, or null when the format is unknown.
(int, int, int)? _keyDate(String s) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  var m = RegExp(r'(\d{4})[/.-](\d{1,2})[/.-](\d{1,2})').firstMatch(s);
  if (m != null) {
    return (int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }
  m = RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})').firstMatch(s);
  if (m != null) {
    final v = int.parse(m[3]!);
    return (int.parse(m[1]!), int.parse(m[2]!), v < 100 ? 2000 + v : v);
  }
  m = RegExp(r'(\d{1,2})[\s-]*([A-Za-z]{3})[A-Za-z]*[\s,.-]*(\d{4}|\d{2})')
      .firstMatch(s);
  if (m != null) {
    final mo = months.indexOf(m[2]!.toUpperCase()) + 1;
    if (mo == 0) return null;
    final v = int.parse(m[3]!);
    return (int.parse(m[1]!), mo, v < 100 ? 2000 + v : v);
  }
  return null;
}

void main() {
  test('tilted scan is straightened and accepted', () {
    final read = ReceiptRules.read(tiltScanLines, now: _farFuture)!;
    expect(read.accepted, true);
    expect(
      read.draft.items.map((i) => i.price).toList(),
      ['26.00', '24.00', '35.00', '34.00', '5.50', '3.00'].map(_d).toList(),
    );
    expect(read.draft.tax, _d('7.65'));
    expect(read.draft.printedTotal, _d('135.15'));
  });

  test('unit prices are removed from item names', () {
    final read = ReceiptRules.read(tiltScanLines, now: _farFuture)!;
    expect(read.draft.items.map((i) => i.name).toList(), [
      'Kimisla (Large)',
      'Kimista (Smal)',
      'Nagoya Mazesoba DX (Large)',
      'Doniku Nagoya Mazesoba (Large)',
      'Korokke',
      'Ajitama',
    ]);
  });

  test('level scan keeps the plain read', () {
    final read = ReceiptRules.read(levelScanLines, now: _farFuture)!;
    expect(read.accepted, false);
    expect(read.draft.items.map((i) => (i.name, _plain(i.price))).toList(), [
      ('Kimtsla (Large)', '26.00'),
      ('Klmista (Simall)', '24.00'),
      ('Nagoya Mazesoba DX (Large})', '35.00'),
      ('Doniku Nagoya Mazesoba (Large)', '34.00'),
      ('Korokke', '5.50'),
    ]);
    expect(read.draft.printedTotal, _d('135.15'));
  });

  test('parses the reply and checks the sum', () {
    final read = ReceiptCloudClient.parse(_reply)!;
    expect(read.draft.items.map((i) => (i.name, _plain(i.price))).toList(), [
      ('Kimista (Large)', '26.00'),
      ('Ajitama', '6.00'),
    ]);
    expect(read.draft.items[1].quantity, 2);
    expect(_plain(read.draft.printedTotal!), '34.30');
    expect(read.accepted, true);
    expect(
      ReceiptCloudClient.parse(_reply.replaceAll('"34.30"', '"35.30"'))!
          .accepted,
      false,
    );
    expect(ReceiptCloudClient.parse('{"items": "none"}'), isNull);
  });

  test('claude wins when it adds up else the rules when they do', () {
    final claudeOk = CloudReadOk(ReceiptCloudClient.parse(_reply)!, 7);
    final claudeOff = CloudReadOk(
      ReceiptCloudClient.parse(_reply.replaceAll('"34.30"', '"35.30"'))!,
      6,
    );
    final good = _rulesRead(true);
    final bad = _rulesRead(false);

    expect(chooseReceiptRead(good, claudeOk), (
      claudeOk.read,
      '✓ Read by Claude · 7 reads left today',
    ));
    expect(identical(chooseReceiptRead(good, claudeOff).$1, good), true);
    expect(
      identical(chooseReceiptRead(bad, claudeOff).$1, claudeOff.read),
      true,
    );
    expect(
      chooseReceiptRead(
        bad,
        const CloudReadFailed('You used your 10 Claude reads for today.'),
      ),
      (bad, 'Read on the phone. You used your 10 Claude reads for today.'),
    );
    expect(chooseReceiptRead(bad, null), (bad, null));
  });

  test(
    'restaurant benchmark',
    () {
      final all = _Stats();
      final restaurant = _Stats();
      final keys =
          Directory('${_benchRoot.path}/sroie/key')
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final keyFile in keys) {
        final name = keyFile.uri.pathSegments.last;
        final id = name.substring(0, name.length - '.json'.length);
        final key =
            jsonDecode(keyFile.readAsStringSync()) as Map<String, dynamic>;
        final truthText = ((key['total'] as String?) ?? '').replaceAll(
          RegExp(r'[^0-9.]'),
          '',
        );
        final truth = Decimal.tryParse(truthText);
        if (truth == null) continue;
        final mlkit = File('${_benchRoot.path}/mlkit/$id.json');
        if (!mlkit.existsSync()) continue;
        final arr =
            (jsonDecode(mlkit.readAsStringSync())
                    as Map<String, dynamic>)['lines']
                as List<dynamic>;
        final lines = [
          for (final o in arr)
            OcrLine(
              (o as Map<String, dynamic>)['text'] as String,
              (o['box'] as List)[0] as int,
              (o['box'] as List)[1] as int,
              (o['box'] as List)[2] as int,
              (o['box'] as List)[3] as int,
            ),
        ];
        final company = (key['company'] as String?) ?? '';
        final read = ReceiptRules.read(lines, now: _farFuture);
        final groups = [all, if (_food.hasMatch(company)) restaurant];
        for (final s in groups) {
          s.n++;
          if (read != null && read.accepted) {
            s.accepted++;
            if (read.draft.printedTotal?.compareTo(truth) == 0) {
              s.correct++;
              s.correctIds.add(id);
            } else {
              s.wrong++;
              s.wrongIds.add(id);
            }
          }
          s.merchantN++;
          final merchant = read?.draft.merchant;
          final m = merchant == null ? null : _norm(merchant);
          final c = _norm(company);
          if (m != null &&
              c.isNotEmpty &&
              (m == c || c.contains(m) || m.contains(c))) {
            s.merchantOk++;
          }
          final kd = _keyDate((key['date'] as String?) ?? '');
          if (kd != null) {
            s.dateN++;
            final ms = read?.draft.dateMillis;
            if (ms != null) {
              final dt = DateTime.fromMillisecondsSinceEpoch(ms);
              if ((dt.day, dt.month, dt.year) == kd) s.dateOk++;
            }
          }
        }
      }
      // ignore: avoid_print
      print(all.report('all'));
      // ignore: avoid_print
      print(restaurant.report('restaurant'));
      // ignore: avoid_print
      print(
        'Benchmark restaurant-correct-ids ${restaurant.correctIds.join(',')}',
      );
      // ignore: avoid_print
      print('Benchmark restaurant-wrong-ids ${restaurant.wrongIds.join(',')}');
      // ignore: avoid_print
      print('Benchmark all-wrong-ids ${all.wrongIds.join(',')}');
      expect(
        restaurant.correct >= 0.73 * restaurant.n,
        true,
        reason:
            'restaurant accepted-correct ${restaurant.correct}/${restaurant.n}',
      );
      expect(restaurant.wrong, 0);
    },
    skip: _hasBench
        ? false
        : 'The git-ignored receipt-bench folder is missing.',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

final tiltScanLines = <OcrLine>[
  OcrLine('Qty Item', 82, 1078, 384, 1155, angle: -3.150235),
  OcrLine('1', 122, 1398, 143, 1442, angle: 0.0),
  OcrLine('TEST RAMEN (SS15)', 492, 152, 1385, 222, angle: 0.8633801),
  OcrLine('TEST FOOD SDN BHD', 644, 223, 1239, 277, angle: 0.0),
  OcrLine(
    'NO.1 JAL AN TEST 1/1, 47500, SUBANG JAYA, SELANGOR',
    139,
    363,
    1720,
    542,
    angle: 2.6593058,
  ),
  OcrLine('Reg no. 200001000001 (100001-X', 435, 286, 1435, 350, angle: 0.0),
  OcrLine('ST NO: B00-0000 00000000', 600, 349, 1344, 408, angle: 0.0),
  OcrLine('6', 200, 1845, 228, 1885, angle: 0.0),
  OcrLine('tnvoc n10001', 90, 735, 617, 800, angle: -1.6647011),
  OcrLine('Date. 07/1 |/2026 1304', 88, 790, 793, 876, angle: -2.102547),
  OcrLine('Role cashter: Cashler', 85, 864, 715, 942, angle: -1.9809605),
  OcrLine('Table pax. 1', 84, 948, 450, 1016, angle: -1.1484855),
  OcrLine('DARUL EHSAN, MALLAYSJA', 574, 475, 1319, 542, angle: -0.7150174),
  OcrLine('+60300000| 00', 750, 539, 1164, 601, angle: -2.329955),
  OcrLine(',test@example.com', 565, 609, 1353, 674, angle: -0.6095095),
  OcrLine(
    'Kimisla (Large) {26.00/ea)',
    262,
    1181,
    1043,
    1292,
    angle: -3.0025706,
  ),
  OcrLine('Kimista (Smal) (24.00/ea)', 295, 1252, 1046, 1371, angle: -3.465116),
  OcrLine(
    'Nagoya Mazesoba DX (Large)',
    277,
    1327,
    1117,
    1445,
    angle: -3.4943957,
  ),
  OcrLine('(35 03/ea)', 288, 1439, 585, 1514, angle: -3.6911335),
  OcrLine(
    'Doniku Nagoya Mazesoba (Large)',
    299,
    1464,
    1226,
    1578,
    angle: -3.397643,
  ),
  OcrLine('(34.00/ea)', 315, 1567, 598, 1642, angle: -3.4805686),
  OcrLine('Qty', 346, 1836, 431, 1890, angle: 0.0),
  OcrLine('Subtotal', 347, 1887, 561, 1949, angle: -3.0711343),
  OcrLine('Korokke (5.50/ea)', 323, 1619, 821, 1706, angle: -3.3747635),
  OcrLine('Ajitama (3.00/ea)', 333, 1686, 812, 1780, angle: -3.600609),
  OcrLine('SST (6%)', 350, 1956, 579, 2025, angle: -2.2220633),
  OcrLine('Bill rounding', 379, 2019, 664, 2091, angle: -1.3795812),
  OcrLine('Total (MYR)', 342, 2138, 795, 2243, angle: -1.6558771),
  OcrLine('TOUCH N GO', 337, 2242, 675, 2306, angle: -2.0805328),
  OcrLine('Change', 333, 2327, 589, 2399, angle: 0.0),
  OcrLine('Charges summary', 175, 2454, 661, 2532, angle: -2.3863745),
  OcrLine('SST 6%', 173, 2536, 367, 2594, angle: -2.2243965),
  OcrLine('This ls an', 624, 2664, 875, 2740, angle: -2.872811),
  OcrLine('Thank yog for vislllng us', 425, 2735, 875, 2803, angle: -3.2573955),
  OcrLine('Feedback & e-Invoice >>', 151, 2811, 774, 2898, angle: -3.0157998),
  OcrLine('Bose Amt.', 1134, 2413, 1395, 2473, angle: -2.3718538),
  OcrLine('127.50', 1229, 2482, 1394, 2535, angle: -1.4932536),
  OcrLine('official recelpt.', 916, 2644, 1270, 2725, angle: -2.8728116),
  OcrLine(
    'Scan the QR code to rate your experlence and',
    146,
    2842,
    1302,
    2975,
    angle: -3.5090919,
  ),
  OcrLine('download your e-Involce.', 139, 2942, 783, 3046, angle: -3.5924501),
  OcrLine(
    'We hope lo ste yol 4ijdl) i0O)!',
    898,
    2701,
    1470,
    2776,
    angle: -3.2573953,
  ),
  OcrLine(
    'Scan the QR code lo yei your e-Invo ie. lu available (run',
    136,
    2965,
    1361,
    3103,
    angle: -4.1067643,
  ),
  OcrLine(
    '30 minutes after payment intil the end of the month',
    147,
    3030,
    1248,
    3161,
    angle: -4.13593,
  ),
  OcrLine('ORDER', 1402, 753, 1575, 804, angle: 2.6182854),
  OcrLine('POWEREO DY TEST POS 1', 599, 3123, 1203, 3215, angle: -4.302272),
  OcrLine('14A', 1401, 838, 1603, 921, angle: 2.2865562),
  OcrLine('Price (MYR)', 1469, 1034, 1768, 1087, angle: 0.7753996),
  OcrLine('26.00', 1637, 1149, 1780, 1202, angle: -1.8268398),
  OcrLine('24.00', 1634, 1221, 1779, 1276, angle: -2.4668925),
  OcrLine('35.00', 1628, 1295, 1789, 1350, angle: -2.4165123),
  OcrLine('34.00', 1619, 1433, 1760, 1483, angle: -1.1392041),
  OcrLine('5.50', 1647, 1570, 1756, 1621, angle: -2.8674028),
  OcrLine('3.00', 1641, 1639, 1754, 1688, angle: -3.3223083),
  OcrLine('127.50', 1575, 1822, 1747, 1877, angle: -3.120083),
  OcrLine('7.65', 1633, 1889, 1797, 1949, angle: -3.386334),
  OcrLine('0.00', 1629, 1964, 1742, 2014, angle: 0.0),
  OcrLine('135.15', 1471, 2095, 1739, 2176, angle: -3.0066981),
  OcrLine('135.15', 1560, 2193, 1734, 2248, angle: -2.3284147),
  OcrLine('0.00', 1585, 2270, 1729, 2332, angle: -0.9175551),
  OcrLine('Amount', 1526, 2407, 1728, 2459, angle: -1.3114573),
  OcrLine('7.65', 1618, 2476, 1729, 2525, angle: 0.0),
];
final levelScanLines = <OcrLine>[
  OcrLine('QUy tem', 124, 943, 380, 998, angle: -0.5007841),
  OcrLine('TEST RAMEN (SS15)', 470, 165, 1246, 249, angle: 2.6312964),
  OcrLine(
    'NO. 1 JAL AN TEST 1/1, 47500, SUBANG JAYA, SELANGOR',
    173,
    339,
    1565,
    523,
    angle: 3.9854946,
  ),
  OcrLine('1', 137, 1343, 158, 1384, angle: 0.0),
  OcrLine(
    'Rey o. 200001000001 (I00 001 x)',
    422,
    280,
    1292,
    363,
    angle: 2.2068553,
  ),
  OcrLine('\$S1 N0: B00-000 00000000', 533, 345, 1209, 415, angle: 1.9026492),
  OcrLine('nvo hR10001', 162, 655, 584, 717, angle: 2.726742),
  OcrLine('Date. 07/11/2026 1304', 130, 711, 735, 784, angle: 2.734995),
  OcrLine('Role.cashter: Cashler', 151, 768, 667, 842, angle: 2.853199),
  OcrLine('Table pax: 1', 127, 829, 430, 895, angle: 3.1574094),
  OcrLine('6', 160, 1635, 183, 1674, angle: 0.0),
  OcrLine('Kimtsla (Large) (26.00/ea)', 267, 1059, 954, 1134, angle: 1.2610381),
  OcrLine(
    'Klmista (Simall) (24.00/e a)',
    268,
    1126,
    961,
    1194,
    angle: 0.56298876,
  ),
  OcrLine('1 Nagoya Mazesoba DX (Large})', 132, 1203, 1024, 1264, angle: 0.0),
  OcrLine('(35.00/ea)', 271, 1269, 536, 1330, angle: 0.77093077),
  OcrLine('DARUL EHSAN MAI.AYSIA', 541, 464, 1191, 523, angle: 1.1435944),
  OcrLine('+60300000|00', 693, 528, 1050, 578, angle: 1.2193583),
  OcrLine('(34.00/ea)', 280, 1403, 539, 1460, angle: 0.0),
  OcrLine('test@example.com', 553, 579, 1221, 646, angle: 1.4077457),
  OcrLine('Doniku Nagoya Mazesoba (Large)', 275, 1334, 1122, 1395, angle: 0.0),
  OcrLine('Qty', 292, 1638, 371, 1692, angle: 0.0),
  OcrLine('Subtotal', 292, 1697, 490, 1744, angle: 0.0),
  OcrLine('Korokke (5.50/ea)', 283, 1467, 741, 1521, angle: 0.0),
  OcrLine('Ajitama (3.00/ea)', 286, 1525, 728, 1585, angle: 0.0),
  OcrLine('SST (6%)', 289, 1756, 504, 1817, angle: 1.2200546),
  OcrLine('Bill rounding', 312, 1819, 588, 1886, angle: 1.3926101),
  OcrLine('Total (MYR)', 280, 1936, 713, 2028, angle: 0.82378983),
  OcrLine('Change', 276, 2102, 518, 2174, angle: 0.5044462),
  OcrLine('TOUCH N GO', 279, 2036, 601, 2084, angle: 0.0),
  OcrLine('Charges summary', 134, 2234, 591, 2292, angle: 0.5359168),
  OcrLine('SST 6%', 134, 2302, 319, 2348, angle: 0.0),
  OcrLine('This is an officlal recelpt.', 583, 2448, 1167, 2507, angle: 0.0),
  OcrLine('Feedback & e-Invoice >>', 125, 2584, 705, 2634, angle: 0.0),
  OcrLine('Bose Amt.', 1038, 2230, 1283, 2276, angle: 0.0),
  OcrLine('127.50', 1126, 2291, 1283, 2340, angle: -0.836593),
  OcrLine('ORDER', 1267, 711, 1429, 754, angle: 1.8005936),
  OcrLine(
    'Scan the QR code to rate your experlence and',
    122,
    2641,
    1203,
    2708,
    angle: 0.0,
  ),
  OcrLine('download your e-Invoice.', 119, 2712, 716, 2772, angle: 0.0),
  OcrLine('14A', 1269, 791, 1451, 864, angle: 0.0),
  OcrLine(
    'Thank you lor vislting us We hope u ste yau ajaln &n\'',
    374,
    2513,
    1362,
    2560,
    angle: 0.0,
  ),
  OcrLine('POWLRED DYLEEDMI SMA:2!', 565, 2905, 1080, 2958, angle: -1.0364349),
  OcrLine(
    'Scan the QR cude lo gei yoụr e lnyo ee i avdilabta fronn',
    136,
    2760,
    1269,
    2826,
    angle: -0.92341346,
  ),
  OcrLine(
    '30 ninufes after payment iintl the etnd of ihe oath',
    115,
    2814,
    1156,
    2882,
    angle: -1.1129439,
  ),
  OcrLine('Price (MYR)', 1328, 967, 1606, 1016, angle: 0.9129626),
  OcrLine('26.00', 1488, 1075, 1617, 1115, angle: 0.0),
  OcrLine('24.00', 1490, 1140, 1619, 1181, angle: 0.0),
  OcrLine('35.00', 1488, 1204, 1620, 1249, angle: 0.0),
  OcrLine('34.00', 1476, 1334, 1605, 1376, angle: 0.0),
  OcrLine('5.50', 1499, 1464, 1598, 1504, angle: 0.0),
  OcrLine('300,', 1514, 1523, 1614, 1574, angle: 0.0),
  OcrLine('127.50', 1433, 1701, 1587, 1742, angle: 0.0),
  OcrLine('7.63', 1488, 1761, 1637, 1812, angle: -1.4202039),
  OcrLine('0.00', 1488, 1826, 1588, 1868, angle: 0.0),
  OcrLine('135.15', 1345, 1946, 1588, 2007, angle: 0.0),
  OcrLine('135.15', 1429, 2034, 1590, 2078, angle: 0.0),
  OcrLine('0.00', 1453, 2101, 1586, 2156, angle: -0.5451608),
  OcrLine('Amount', 1404, 2230, 1588, 2273, angle: 0.0),
  OcrLine('7.65', 1489, 2291, 1589, 2336, angle: 0.0),
];
