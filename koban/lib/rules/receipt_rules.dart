import 'dart:math' as math;
import 'dart:typed_data';

import 'package:decimal/decimal.dart';

/// One item line of a receipt. [price] is the line total, not the unit price.
class ReceiptItemDraft {
  const ReceiptItemDraft(this.name, this.quantity, this.price);

  final String name;
  final int quantity;
  final Decimal price;

  ReceiptItemDraft _withName(String name) =>
      ReceiptItemDraft(name, quantity, price);

  @override
  bool operator ==(Object other) =>
      other is ReceiptItemDraft &&
      other.name == name &&
      other.quantity == quantity &&
      other.price == price;

  @override
  int get hashCode => Object.hash(name, quantity, price);

  @override
  String toString() => 'ReceiptItemDraft($name, $quantity, $price)';
}

/// What the rules read from one receipt.
class ReceiptDraft {
  const ReceiptDraft({
    required this.merchant,
    required this.dateMillis,
    required this.items,
    required this.serviceCharge,
    required this.tax,
    required this.discount,
    required this.rounding,
    required this.printedTotal,
  });

  final String? merchant;
  final int? dateMillis;
  final List<ReceiptItemDraft> items;
  final Decimal serviceCharge;
  final Decimal tax;
  final Decimal discount;
  final Decimal rounding;
  final Decimal? printedTotal;
}

/// One recognized text line with its box in image pixels. [angle] is the line
/// rotation in degrees from ML Kit (0 if unknown).
class OcrLine {
  const OcrLine(
    this.text,
    this.left,
    this.top,
    this.right,
    this.bottom, {
    this.angle = 0.0,
  });

  final String text;
  final int left;
  final int top;
  final int right;
  final int bottom;
  final double angle;
}

/// The result of [ReceiptRules.read]. [calculated] holds display phrases for
/// charges the rules computed, for example "10% service charge".
class ReceiptRead {
  const ReceiptRead(this.draft, this.accepted, this.calculated);

  final ReceiptDraft draft;
  final bool accepted;
  final List<String> calculated;
}

/// The result of [ReceiptRules.parse].
class ParsedReceipt {
  const ParsedReceipt(
    this.items,
    this.subtotal,
    this.serviceCharge,
    this.tax,
    this.discount,
    this.rounding,
    this.totals, {
    this.nameBelowHint = false,
  });

  final List<ReceiptItemDraft> items;
  final Decimal? subtotal;
  final Decimal serviceCharge;
  final Decimal tax;
  final Decimal discount;
  final Decimal rounding;
  final List<Decimal> totals;
  final bool nameBelowHint;

  ParsedReceipt _withoutHint() => ParsedReceipt(
    items,
    subtotal,
    serviceCharge,
    tax,
    discount,
    rounding,
    totals,
  );
}

class _Reading {
  const _Reading(
    this.value,
    this.sc,
    this.tax,
    this.disc,
    this.rnd, [
    this.calculated = const [],
  ]);

  final Decimal value;
  final Decimal sc;
  final Decimal tax;
  final Decimal disc;
  final Decimal rnd;
  final List<String> calculated;
}

class _Band {
  _Band(this.cy, this.h, int left, String text) : parts = [(left, text)];

  final double cy;
  final int h;
  final List<(int, String)> parts;
}

RegExp _ci(String pattern) => RegExp(pattern, caseSensitive: false);

RegExp _kw(List<String> words) =>
    _ci('(?<![A-Z])(?:${words.join('|')})(?![A-Z])');

/// Rule based receipt reading: OCR lines to rows, repaired rows, then items,
/// charges and totals. Pure Dart.
abstract final class ReceiptRules {
  static final Decimal _zero = Decimal.zero;

  static const String _amount =
      r'-?(?:RM\s*|\$)?\(?(?<![\d,.])(?:\d{1,3}(?:,\d{3})+|\d+)\.\d{2}\)?-?';
  static final RegExp _tail = _ci(
    '($_amount)'
    r'\s*(?:[A-Z]{1,3}-?\d?|\*\w?|#)?\s*$',
  );
  static final RegExp _qtyX = RegExp(
    r'(\d+(?:\.\d+)?)\s*[xX@*]\s*(?:RM\s*)?(\d+\.\d{2})',
  );
  static final RegExp _leadQty = RegExp(r'^(\d{1,2})\s+([A-Za-z].*)$');
  static final RegExp _leadNumberColumns = RegExp(
    r'^(\d{1,2})\s+\d+\.\d{2}\s*$',
  );

  /// A unit price after an item name, "(26.00/ea)". OCR may read the "(" as "{"
  /// or the "." as a space.
  static final RegExp _unitPrice = _ci(
    r'\s*[({]\s*\d+[.,\s]?\d{0,2}\s*/\s*e\s*a\s*\)?\s*$',
  );
  static final RegExp _trailingNumbers = _ci(
    '(\\s+$_amount|\\s+\\d+(?:\\.\\d+)?)+'
    r'\s*$',
  );

  static final RegExp _subtotal = _kw([
    r'SUB\s*-?\s*TOTAL',
    r'TOTAL\s*\(?\s*EXCL\w*',
    r'TOTAL\s+BEFORE',
    r'NET\s+SALES',
  ]);
  static final RegExp _total = _kw([
    r'GRAND\s+TOTAL',
    r'NETT?\s+TOTAL',
    r'TOTAL\s+AMOUNT',
    r'TOTAL\s+INCL\w*',
    r'TOTAL\s+SALES',
    r'TOTAL\s+PAYABLE',
    r'AMOUNT\s+DUE',
    r'AMT\s+DUE',
    r'TOTAL\s+DUE',
    'JUMLAH',
    'TOTAL',
    r'TOTAL\s*\(RM\)',
    'NETT',
  ]);
  static final RegExp _notTotal = _kw([
    r'TOTAL\s+QTY',
    r'TOTAL\s+QUANTITY',
    r'TOTAL\s+ITEMS?',
    r'TOTAL\s+DISC\w*',
    r'TOTAL\s+GST',
    r'TOTAL\s+TAX',
    r'TOTAL\s+SAVING\w*',
    r'TOTAL\s+NO',
    r'ITEM\s*\(S\)',
    'QTY',
    r'TOTAL\s+EXCL\w*',
  ]);
  static final RegExp _service = _kw([
    r'SERVICE\s+CHARGE',
    r'SERV\w*\.?\s*CH\w*',
    r'SVC\s*CHG',
    'SVC',
    'S/C',
    r'SERV\.?\s*CHG',
    r'SERVICE\s+CHG',
    r'SC\s*\d+\s*%',
  ]);
  static final RegExp _taxWord = _kw([
    'GST',
    'SST',
    'TAX',
    r'SERVICE\s+TAX',
    'VAT',
  ]);
  static final RegExp _roundingWord = _kw([
    'ROUNDING',
    r'ROUND\w*\s+ADJ\w*',
    'RND',
    r'ADJ\w*',
  ]);
  static final RegExp _discount = _kw([
    'DISCOUNT',
    'DISC',
    'VOUCHER',
    'LESS',
    'PROMO',
  ]);
  static final RegExp _payment = _kw([
    'CASH',
    'CHANGE',
    'BAKI',
    r'TENDER\w*',
    'VISA',
    r'MASTER\w*',
    'CARD',
    'PAID',
    'PAYMENT',
    'CREDIT',
    'DEBIT',
    'TNG',
    'E-?WALLET',
    'BOOST',
    'GRABPAY',
    'AMEX',
    'RECEIVED',
  ]);
  static final RegExp _skipItem = _kw([
    'TEL',
    'FAX',
    r'GST\s*(?:REG|ID|NO)',
    'INV',
    'RECEIPT',
    'DATE',
    'TIME',
    'TABLE',
    'PAX',
    'CASHIER',
    'BILL',
    'POINTS?',
    'BALANCE',
    'MEMBER',
  ]);
  static final RegExp _stop = _kw(['SUMMARY', r'TAX\s+CODE', 'CHANGE', 'BAKI']);
  static final RegExp _serviceTax = _ci(r'SERVICE\s+TAX');
  static final RegExp _included = _ci('INCLUDED|INCL');

  static const List<String> _vocab = [
    'TOTAL',
    'SUBTOTAL',
    'AMOUNT',
    'SERVICE',
    'CHARGE',
    'ROUNDING',
    'DISCOUNT',
    'CHANGE',
    'CASH',
    'INCLUSIVE',
    'EXCLUDING',
    'PAYABLE',
    'GRAND',
    'SALES',
    'NETT',
    'SERV',
    'TENDER',
    'BALANCE',
    'SUMMARY',
  ];

  /// Four-letter words match only exactly (CASE is not CASH). SERY is an OCR
  /// form of SERV.
  static final Map<String, String> _fourLetter = {
    for (final v in _vocab)
      if (v.length == 4) v: v,
    'SERY': 'SERV',
  };

  static Decimal _money(String s) {
    final t = s
        .toUpperCase()
        .replaceAll('RM', '')
        .replaceAll(r'$', '')
        .replaceAll(',', '')
        .replaceAll(' ', '');
    final neg = t.startsWith('-') || t.endsWith('-') || t.startsWith('(');
    final v = Decimal.parse(t.replaceAll(RegExp(r'^[-()]+|[-()]+$'), ''));
    return neg ? -v : v;
  }

  /// Undo a tilted photo: move each line's vertical center by -x * tan(median
  /// angle of the wide lines). On a tilted receipt the right-hand price column
  /// sits higher or lower than its names. Short lines often report 0 degrees,
  /// so only lines wider than 300 px vote. No usable angle: the same list is
  /// returned.
  static List<OcrLine> straighten(List<OcrLine> lines) {
    final angles =
        lines
            .where((l) => l.right - l.left > 300 && l.angle != 0.0)
            .map((l) => l.angle)
            .toList()
          ..sort();
    if (angles.isEmpty) return lines;
    // Kotlin keeps the angle as a 32-bit Float. Round the same way.
    final median = Float32List.fromList([angles[angles.length ~/ 2]])[0];
    final k = math.tan(median * 0.017453292519943295);
    return [
      for (final l in lines)
        () {
          final shift = (-(l.left + l.right) / 2.0 * k).toInt();
          return OcrLine(
            l.text,
            l.left,
            l.top + shift,
            l.right,
            l.bottom + shift,
            angle: l.angle,
          );
        }(),
    ];
  }

  /// Join lines whose vertical centers sit inside one row band, left to right,
  /// one space between parts.
  static List<String> rows(List<OcrLine> lines) {
    final bands = <_Band>[];
    // Dart sort is not stable. The index keeps equal centers in input order.
    final order = [for (var i = 0; i < lines.length; i++) i]
      ..sort((a, b) {
        final c = ((lines[a].top + lines[a].bottom) / 2.0).compareTo(
          (lines[b].top + lines[b].bottom) / 2.0,
        );
        return c != 0 ? c : a.compareTo(b);
      });
    for (final i in order) {
      final l = lines[i];
      final cy = (l.top + l.bottom) / 2.0;
      final h = math.max(1, l.bottom - l.top);
      _Band? band;
      for (final b in bands) {
        if ((b.cy - cy).abs() < 0.5 * math.min(h, b.h)) {
          band = b;
          break;
        }
      }
      if (band != null) {
        band.parts.add((l.left, l.text));
      } else {
        bands.add(_Band(cy, h, l.left, l.text));
      }
    }
    return [
      for (final b in bands)
        (b.parts..sort((x, y) {
              final c = x.$1.compareTo(y.$1);
              return c != 0 ? c : x.$2.compareTo(y.$2);
            }))
            .map((p) => p.$2)
            .join(' ')
            .trim(),
    ];
  }

  /// Repair OCR damage on amounts at the end of a row: "14 00", "79, 60",
  /// "-0. 03", "1O.50".
  static String fixRow(String row) {
    var r = row.replaceAll(
      RegExp(r'(?<=\d)[oO](?=[\d.,])|(?<=[\d.,])[oO](?=\d)'),
      '0',
    );
    r = r.replaceAllMapped(
      RegExp(r'(\d)\s*[,.]\s+(\d{2})(\s*[A-Za-z]{0,3}\s*)$'),
      (m) => '${m[1]}.${m[2]}${m[3]}',
    );
    r = r.replaceAllMapped(
      RegExp(r'(\d),(\d{2})(\s*[A-Za-z]{0,3}\s*)$'),
      (m) => '${m[1]}.${m[2]}${m[3]}',
    );
    r = r.replaceAllMapped(
      RegExp(r'(?<![\d.,:/])(\d{1,4}) (\d{2})(\s*[A-Za-z]{0,3}\s*)$'),
      (m) => '${m[1]}.${m[2]}${m[3]}',
    );
    return r;
  }

  static final RegExp _labelWord = RegExp(r'[A-Za-z0-9%@#/().:-]+');

  /// Fuzzy-correct label words for keyword matching only ("SULTOTAL" to
  /// "SUBTOTAL", "T0TAL" to "TOTAL").
  static String normLabel(String label) => _labelWord
      .allMatches(label.toUpperCase().replaceAll('0', 'O'))
      .map((m) {
        final w = m[0]!;
        final core = w.replaceAll(RegExp('[^A-Z]'), '');
        if (core.length == 4) return _fourLetter[core] ?? w;
        if (core.length >= 5) return _closestWord(core) ?? w;
        return w;
      })
      .join(' ');

  static String? _closestWord(String core) {
    String? best;
    var bestSim = 0.75 - 1e-9;
    for (final v in _vocab) {
      if (v[0] != core[0]) continue;
      final sim = 1.0 - _levenshtein(core, v) / math.max(core.length, v.length);
      if (sim > bestSim) {
        best = v;
        bestSim = sim;
      }
    }
    return best;
  }

  static int _levenshtein(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        cur[j] = math.min(
          math.min(prev[j] + 1, cur[j - 1] + 1),
          prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        );
      }
      prev = cur;
    }
    return prev[b.length];
  }

  static final RegExp _headerQty = _ci('(?<![A-Z])QTY(?![A-Z])');
  static final RegExp _headerName = _ci(
    r'(?<![A-Z])(?:DESC\w*|ITEMS?)(?![A-Z])',
  );
  static final RegExp _headerPrice = _ci(
    r'(?<![A-Z])(?:TOTAL|AMOUNT|PRICE|AMT)(?![A-Z])',
  );
  static final RegExp _threeLetters = RegExp('[A-Za-z]{3}');
  static final RegExp _twoLetters = RegExp('[A-Za-z]{2}');
  static final RegExp _alnum = RegExp('[A-Za-z0-9]');

  /// A tilted scan can put each price row one row above its name. The first
  /// pass pairs names above. If the first item had no name above it and a name
  /// row is left after the last item, parse again with `nameBelow`.
  static ParsedReceipt parse(List<String> rows) {
    final first = _parse(rows, false);
    return first.nameBelowHint ? _parse(rows, true)._withoutHint() : first;
  }

  static int _toQty(String digits) {
    final n = Decimal.parse(digits).truncate().toBigInt().toInt();
    return n == 0 ? 1 : n;
  }

  static ParsedReceipt _parse(List<String> rows, bool nameBelow) {
    final items = <ReceiptItemDraft>[];
    final sc = <Decimal>[];
    final tax = <Decimal>[];
    final disc = <Decimal>[];
    final rnd = <Decimal>[];
    final totals = <Decimal>[];
    Decimal? subtotal;
    var inItems = true;
    var firstNameless = false;
    var trailingName = false;
    // nameBelow: index of the item still waiting for the name row below it.
    var pending = -1;
    // Text rows since the last item: the last one names an item whose numbers
    // sit lower.
    final names = <String>[];
    void leaveItems() {
      if (inItems && names.isNotEmpty) trailingName = true;
      inItems = false;
    }

    for (final raw in rows) {
      final row = fixRow(raw);
      if (_headerQty.hasMatch(row) &&
          _headerName.hasMatch(row) &&
          _headerPrice.hasMatch(row)) {
        names.clear();
        continue;
      }
      final m = _tail.firstMatch(row);
      if (_stop.hasMatch(normLabel(row)) &&
          (m != null || row.toUpperCase().contains('SUMMARY'))) {
        break;
      }
      if (m == null) {
        if (_threeLetters.hasMatch(row) && !_skipItem.hasMatch(row)) {
          if (nameBelow && inItems && pending >= 0) {
            items[pending] = items[pending]._withName(row);
            pending = -1;
          } else {
            names.add(row);
          }
        }
        continue;
      }
      final amt = _money(m[1]!);
      final rawLabel = row.substring(0, m.start).trim();
      final label = normLabel(rawLabel);
      if (_payment.hasMatch(label) && !_total.hasMatch(label)) {
        if (totals.isNotEmpty) break;
        continue;
      }
      final discountHit = _discount.firstMatch(label);
      if (_subtotal.hasMatch(label)) {
        leaveItems();
        subtotal ??= amt;
      } else if (_service.hasMatch(label) && !_serviceTax.hasMatch(label)) {
        leaveItems();
        sc.add(amt);
      } else if (_total.hasMatch(label) || _notTotal.hasMatch(label)) {
        leaveItems();
        if (!_notTotal.hasMatch(label)) totals.add(amt);
      } else if (_taxWord.hasMatch(label)) {
        leaveItems();
        if (!_included.hasMatch(label)) tax.add(amt);
      } else if (_roundingWord.hasMatch(label)) {
        leaveItems();
        rnd.add(amt);
      } else if (discountHit != null &&
          (discountHit.start == 0 || amt.sign < 0)) {
        disc.add(amt.abs());
      } else if (inItems &&
          !_alnum.hasMatch(label) &&
          items.isNotEmpty &&
          names.isEmpty &&
          items.last.price == amt) {
        continue; // the line total printed again under its row
      } else if (inItems && !_skipItem.hasMatch(label)) {
        var name = rawLabel;
        var qty = 1;
        final q = _qtyX.firstMatch(row);
        if (q != null) {
          qty = _toQty(q[1]!);
          name = row.substring(0, q.start).trim();
        }
        name = ' $name'
            .replaceAll(_trailingNumbers, '')
            .trim()
            .replaceAll(_unitPrice, '');
        final lq = _leadQty.firstMatch(name);
        if (lq != null && q == null) {
          qty = int.parse(lq[1]!);
          if (qty == 0) qty = 1;
          name = lq[2]!;
        }
        var nameless = false;
        if (!_twoLetters.hasMatch(name)) {
          nameless = true;
          if (items.isEmpty && names.isEmpty) firstNameless = true;
          name = nameBelow ? 'Item' : (names.isEmpty ? 'Item' : names.last);
          // "4 3.50 14.00": no name, the leading count is the quantity.
          if (q == null) {
            final c = _leadNumberColumns.firstMatch(rawLabel);
            if (c != null) {
              qty = int.parse(c[1]!);
              if (qty == 0) qty = 1;
            }
          }
        }
        if (amt.sign < 0) {
          disc.add(-amt);
        } else if (amt.sign > 0) {
          items.add(ReceiptItemDraft(name, qty, amt));
          if (nameBelow && nameless) pending = items.length - 1;
        }
        names.clear();
      }
    }
    if (inItems && names.isNotEmpty) trailingName = true;
    Decimal sum(List<Decimal> l) => l.fold(_zero, (a, b) => a + b);
    return ParsedReceipt(
      items,
      subtotal,
      sum(sc),
      sum(tax),
      sum(disc),
      sum(rnd),
      totals,
      nameBelowHint: !nameBelow && firstNameless && trailingName,
    );
  }

  /// Readings 1 to 6 of the spec, in order.
  static List<_Reading> _readings(ParsedReceipt p) {
    final s = p.items.fold(_zero, (a, i) => a + i.price);
    final sc = p.serviceCharge;
    final tax = p.tax;
    final disc = p.discount;
    final rnd = p.rounding;
    final out = <_Reading>[
      _Reading(s, _zero, _zero, _zero, _zero),
      _Reading(s + rnd, _zero, _zero, _zero, rnd),
      _Reading(s - disc + rnd, _zero, _zero, disc, rnd),
      _Reading(s + sc + tax - disc + rnd, sc, tax, disc, rnd),
      _Reading(s + sc - disc + rnd, sc, _zero, disc, rnd),
    ];
    final base = s - disc;
    final scRates = <Decimal?>[if (sc.sign == 0) Decimal.parse('0.10'), null];
    final txRates = <Decimal?>[
      if (tax.sign == 0) ...[Decimal.parse('0.06'), Decimal.parse('0.08')],
      null,
    ];
    for (final scRate in scRates) {
      final sc2 = scRate != null ? (base * scRate).round(scale: 2) : sc;
      for (final txRate in txRates) {
        if (scRate == null && txRate == null) continue;
        final tx2 = txRate != null
            ? ((base + sc2) * txRate).round(scale: 2)
            : tax;
        final phrases = [
          if (scRate != null) '10% service charge',
          if (txRate != null)
            '${(txRate * Decimal.fromInt(100)).toBigInt().toInt()}% SST',
        ];
        out.add(_Reading(base + sc2 + tx2 + rnd, sc2, tx2, disc, rnd, phrases));
      }
    }
    return out;
  }

  /// Null when the lines hold no item and no printed total. The lines are read
  /// as they are first. The straightened read is used only when it adds up and
  /// the plain read does not. ML Kit also reports small angles on a curled but
  /// level receipt, so straightening an accepted read can only make it worse.
  ///
  /// [now] is in milliseconds since epoch. A receipt date after [now] is null.
  static ReceiptRead? read(List<OcrLine> lines, {int? now}) {
    final at = now ?? DateTime.now().millisecondsSinceEpoch;
    final plain = _readRows(rows(lines), at);
    if (plain?.accepted == true) return plain;
    final straightened = straighten(lines);
    final straight = identical(straightened, lines)
        ? null
        : _readRows(rows(straightened), at);
    return straight?.accepted == true ? straight : plain;
  }

  static final Decimal _tolerance = Decimal.parse('0.01');

  static ReceiptRead? _readRows(List<String> rows, int now) {
    final p = parse(rows);
    final total = p.totals.isEmpty ? null : p.totals.last;
    final printed = total ?? p.subtotal;
    if (p.items.isEmpty && printed == null) return null;

    _Reading? hit;
    var rounding = p.rounding;
    if (total != null && p.items.isNotEmpty) {
      final rs = _readings(p);
      hit = rs.where((r) => (r.value - total).abs() <= _tolerance).firstOrNull;
      // A total on a five sen step may be off by two sen.
      if (hit == null && (total * Decimal.fromInt(20)).isInteger) {
        final wide = Decimal.parse('0.02');
        hit = rs.where((r) => (r.value - total).abs() <= wide).firstOrNull;
      }
      if (hit != null) rounding = hit.rnd + (total - hit.value);
    }
    final draft = ReceiptDraft(
      merchant: _merchant(rows),
      dateMillis: _date(rows, now),
      items: p.items,
      serviceCharge: hit?.sc ?? p.serviceCharge,
      tax: hit?.tax ?? p.tax,
      discount: hit?.disc ?? p.discount,
      rounding: rounding,
      printedTotal: printed,
    );
    return ReceiptRead(draft, hit != null, hit?.calculated ?? const []);
  }

  static final RegExp _notMerchant = _ci(
    r'^(?:TAX\s+)?(?:INVOI\s*CE|RECEIPT)\W*$',
  );
  static final RegExp _address = _ci(
    r'(?<![A-Z])(?:NO\.|(?:JALAN|JLN|LORONG|LRG|TAMAN|TMN|KAWASAN|BANDAR|PERSIARAN|LEBUH|KUALA|SELANGOR|JOHOR|PENANG|'
    r'PERAK|KEDAH|MELAKA|SABAH|SARAWAK|PAHANG|KELANTAN|TERENGGANU|TEL|FAX|GST|SST|REG|COMPANY|CASHIER|DATE|WWW|'
    r'THANK|TQ|WELCOME|INVOICE|QTY|CASH\s+SALE)(?![A-Z]))|\.COM|(?<!\d)\d{5}(?!\d)',
  );
  static final RegExp _legalOnly = _ci(
    r'(?<![A-Z])(?:SDN|BHD|S/B)(?![A-Z])|\([^)]*\)',
  );
  static final RegExp _companyNo = _ci(
    r'\s*[(\[{]\s*\d{4,}\s*-?\s*[A-Z]?\s*[)\]}]?\s*$',
  );
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _digit = RegExp(r'\p{Nd}', unicode: true);

  /// Count the UTF-16 units that match, as Kotlin Char.isLetter does.
  static int _count(String s, RegExp unit) =>
      s.codeUnits.where((c) => unit.hasMatch(String.fromCharCode(c))).length;

  static String? _merchant(List<String> rows) {
    final candidates = rows.take(8).where((r) {
      final letters = _count(r, _letter);
      return letters >= 3 &&
          letters > _count(r, _digit) &&
          !_notMerchant.hasMatch(r.trim()) &&
          !_address.hasMatch(r) &&
          _count(r.replaceAll(_legalOnly, ''), _letter) >= 3;
    });
    return candidates.firstOrNull?.replaceAll(_companyNo, '').trim();
  }

  static const List<String> _months = [
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
  static final RegExp _dmy = RegExp(
    r'(?<!\d)(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|\d{2})(?!\d)',
  );
  static final RegExp _dmony = _ci(
    r'(?<!\d)(\d{1,2})\s+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\.?,?\s+(\d{4}|\d{2})(?!\d)',
  );
  static final RegExp _ymd = RegExp(
    r'(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)',
  );

  /// The first date in the text, day first, as local midnight. An impossible
  /// date or one after [now] is null.
  static int? _date(List<String> rows, int now) {
    final text = rows.join('\n');
    final found = <(int, String, String, String)>[
      if (_dmy.firstMatch(text) case final m?) (m.start, m[3]!, m[2]!, m[1]!),
      if (_dmony.firstMatch(text) case final m?)
        (
          m.start,
          m[3]!,
          (_months.indexOf(m[2]!.toUpperCase()) + 1).toString(),
          m[1]!,
        ),
      if (_ymd.firstMatch(text) case final m?) (m.start, m[1]!, m[2]!, m[3]!),
    ];
    if (found.isEmpty) return null;
    var best = found.first;
    for (final f in found) {
      if (f.$1 < best.$1) best = f;
    }
    final y = best.$2;
    final month = int.parse(best.$3);
    final day = int.parse(best.$4);
    final year = y.length == 2 ? 2000 + int.parse(y) : int.parse(y);
    // Dart DateTime accepts month 13 and day 32. Kotlin does not. Check back.
    final dt = DateTime(year, month, day);
    if (year < 1 || dt.year != year || dt.month != month || dt.day != day) {
      return null;
    }
    final ms = dt.millisecondsSinceEpoch;
    return ms <= now ? ms : null;
  }
}
