import 'dart:convert';

import 'package:decimal/decimal.dart';

import 'receipt_rules.dart';

/// The answer of the cloud read. Only the reply parser and the choice rule are
/// here. The network call is not part of the pure rules.
sealed class CloudRead {
  const CloudRead();
}

/// Claude read the receipt. [readsLeft] is null when the reply has no count.
final class CloudReadOk extends CloudRead {
  const CloudReadOk(this.read, this.readsLeft);

  final ReceiptRead read;
  final int? readsLeft;
}

/// Claude did not read the receipt. [why] completes "Read on the phone. ...".
final class CloudReadFailed extends CloudRead {
  const CloudReadFailed(
    this.why, {
    this.tokenRevoked = false,
    this.usedRead = false,
  });

  final String why;
  final bool tokenRevoked;
  final bool usedRead;
}

abstract final class ReceiptCloudClient {
  /// The 200 reply as a read. Accepted when items and charges add up to the
  /// printed total exactly. Null when the reply is not valid.
  static ReceiptRead? parse(String json) {
    try {
      final j = jsonDecode(json) as Map<String, dynamic>;
      final items = [
        for (final o in j['items'] as List<dynamic>)
          ?_item(o as Map<String, dynamic>),
      ];
      Decimal money(String key) => _decimal(j[key]) ?? Decimal.zero;
      final total = _decimal(j['total']);
      final merchant = _text(j['merchant']);
      final draft = ReceiptDraft(
        merchant: merchant,
        dateMillis: _date(_text(j['date']) ?? ''),
        items: items,
        serviceCharge: money('serviceCharge'),
        tax: money('tax'),
        discount: money('discount'),
        rounding: money('rounding'),
        printedTotal: total,
      );
      final sum =
          items.fold(Decimal.zero, (a, i) => a + i.price) +
          draft.serviceCharge +
          draft.tax -
          draft.discount +
          draft.rounding;
      return ReceiptRead(draft, total != null && sum == total, const []);
    } catch (_) {
      return null;
    }
  }

  /// An item, or null when it has no name or no positive price.
  static ReceiptItemDraft? _item(Map<String, dynamic> o) {
    final name = o['name'] as String;
    final price = Decimal.parse(o['price'].toString());
    final q = o['quantity'];
    final quantity = q is num ? q.toInt() : int.tryParse('$q') ?? 1;
    if (name.trim().isEmpty || price.sign <= 0) return null;
    return ReceiptItemDraft(name, quantity < 1 ? 1 : quantity, price);
  }

  static String? _text(Object? v) {
    final s = v?.toString() ?? '';
    return s.trim().isEmpty || s == 'null' ? null : s;
  }

  static Decimal? _decimal(Object? v) {
    final s = _text(v);
    return s == null ? null : Decimal.parse(s);
  }

  /// "YYYY-MM-DD" to local midnight, the same as [ReceiptRules] gives.
  static int? _date(String text) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (m == null) return null;
    final y = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    final dt = DateTime(y, mo, d);
    return y < 1 || dt.year != y || dt.month != mo || dt.day != d
        ? null
        : dt.millisecondsSinceEpoch;
  }
}

String _claudeLine(int? readsLeft) =>
    '✓ Read by Claude${readsLeft == null ? '' : ' · $readsLeft reads left today'}';

/// Claude's read if it adds up. Else the rules' read if it adds up. Else
/// Claude's read. Without Claude: the rules' read, with a line that says why
/// Claude did not run.
(ReceiptRead?, String?) chooseReceiptRead(
  ReceiptRead? rules,
  CloudRead? cloud,
) => switch (cloud) {
  null => (rules, null),
  CloudReadFailed() => (rules, 'Read on the phone. ${cloud.why}'),
  CloudReadOk() when cloud.read.accepted => (
    cloud.read,
    _claudeLine(cloud.readsLeft),
  ),
  CloudReadOk() when rules?.accepted == true => (
    rules,
    "Read on the phone: Claude's read did not match the receipt total.",
  ),
  CloudReadOk() => (cloud.read, _claudeLine(cloud.readsLeft)),
};
