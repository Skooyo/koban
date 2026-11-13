import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/payment_rules.dart';
import 'package:koban/rules/types.dart';

const maybank = 'com.maybank2u.life';
const tng = 'my.com.tngdigital.ewallet';
const wallet = 'com.google.android.apps.walletnfcrel';
const other = 'com.example.bank';

void known(
  String pkg,
  String text,
  String amount,
  String? merchant,
  TransactionType type,
) {
  final match = PaymentRules.match(pkg, text);
  expect(match, isA<Matched>());
  match as Matched;
  expect(match.format, CaptureFormat.known);
  expect(match.expense.amount, Decimal.parse(amount));
  expect(match.expense.merchant, merchant);
  expect(match.expense.transactionType, type);
  expect(match.expense.directionClear, true);
}

/// Catch-all: an amount with no strict shape becomes an unknown card.
void caught(
  String pkg,
  String text,
  String amount,
  TransactionType type,
  bool clear,
) {
  final match = PaymentRules.match(pkg, text);
  expect(match, isA<Matched>());
  match as Matched;
  expect(match.format, CaptureFormat.unknown);
  expect(match.expense.amount, Decimal.parse(amount));
  expect(match.expense.transactionType, type);
  expect(match.expense.directionClear, clear);
}

void main() {
  test(
    'maybank card spend',
    () => known(
      maybank,
      "You've just spent RM 23.40 at KEDAI RUNCIT AMAN with your Maybank Debit Card Visa ending 1234. View your receipt now.",
      '23.40',
      'KEDAI RUNCIT AMAN',
      TransactionType.withdraw,
    ),
  );

  test(
    'maybank QR payment',
    () => known(
      maybank,
      'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.',
      '15.00',
      'RESTORAN CONTOH',
      TransactionType.withdraw,
    ),
  );

  test(
    'maybank QR payment ref suffix',
    () => known(
      maybank,
      'Successful payment of RM 8.00 to KOPI CONTOH. REF: 123456Q.',
      '8.00',
      'KOPI CONTOH',
      TransactionType.withdraw,
    ),
  );

  test(
    'maybank M2U paid',
    () => known(
      maybank,
      'M2U: You have successfully paid RM12.00 to CONTOH SDN BHD.',
      '12.00',
      'CONTOH SDN BHD',
      TransactionType.withdraw,
    ),
  );

  test(
    'maybank transfer',
    () => known(
      maybank,
      "You've transferred RM 50.00 to ALI BIN ABU. REF: 123456M",
      '50.00',
      'ALI BIN ABU',
      TransactionType.withdraw,
    ),
  );

  test(
    'maybank withdrawal',
    () => known(
      maybank,
      "You've successfully withdrawn RM 100.00 from your account ending 1234.",
      '100.00',
      'ATM withdrawal',
      TransactionType.withdraw,
    ),
  );

  test(
    'maybank received',
    () => known(
      maybank,
      "You've received RM 40.00 from SITI AMINAH. REF: 123456Q",
      '40.00',
      'SITI AMINAH',
      TransactionType.receive,
    ),
  );

  test(
    'maybank received to account',
    () => known(
      maybank,
      "You've just received RM 40.00 in your account ending ***1234. REF: 123ABC456",
      '40.00',
      null,
      TransactionType.receive,
    ),
  );

  test(
    'tng paid',
    () => known(
      tng,
      'You have paid RM12.50 to CONTOH CAFE.',
      '12.50',
      'CONTOH CAFE',
      TransactionType.withdraw,
    ),
  );

  test(
    'tng transferred',
    () => known(
      tng,
      'RM 30.00 has been successfully transferred to ALI BIN ABU.',
      '30.00',
      'ALI BIN ABU',
      TransactionType.withdraw,
    ),
  );

  test(
    'tng transferred with prefix',
    () => known(
      tng,
      'Transfer Successful. RM 30.00 has been successfully transferred to ALI BIN ABU.',
      '30.00',
      'ALI BIN ABU',
      TransactionType.withdraw,
    ),
  );

  test(
    'tng received',
    () => known(
      tng,
      'RM 20.00 received from SITI AMINAH.',
      '20.00',
      'SITI AMINAH',
      TransactionType.receive,
    ),
  );

  test(
    'maybank transfer limit caught unclear',
    () => caught(
      maybank,
      'Your new transfer limit of RM 5000.00 for Interbank Transfer will be reflected after 12 hour(s). Not you? Call Maybank now.',
      '5000.00',
      TransactionType.withdraw,
      false,
    ),
  );

  test(
    'maybank rate offer no match',
    () => expect(
      PaymentRules.match(maybank, 'Get eIFD-i rates up to 3.85% via FPX.'),
      isA<NoMatch>(),
    ),
  );

  test(
    'maybank promotion with payment word caught unclear',
    () => caught(
      maybank,
      'Pay RM1 and win a trip! Spend RM 50 at any partner to join.',
      '1.00',
      TransactionType.withdraw,
      false,
    ),
  );

  test(
    'tng promo with amount now caught',
    () => caught(
      tng,
      'Harga emas turun hari ini. Miliki emas mulai RM10 saja dengan TNG eWallet!',
      '10.00',
      TransactionType.withdraw,
      false,
    ),
  );

  test(
    'tng discount promo caught unclear',
    () => caught(
      tng,
      'Kamu kebagian akses ke Payday Flash Deals! Klaim diskon RM50 buat tiket pesawat.',
      '50.00',
      TransactionType.withdraw,
      false,
    ),
  );

  test(
    'google wallet card tap caught unclear',
    () => caught(
      wallet,
      'MYR23.40 with Maybank Visa Platinum Debit ••1234',
      '23.40',
      TransactionType.withdraw,
      false,
    ),
  );

  test(
    'maybank unknown shape falls back to generic',
    () => caught(
      maybank,
      'Payment RM 12.30 to CONTOH MART is successful.',
      '12.30',
      TransactionType.withdraw,
      true,
    ),
  );

  test(
    'generic rule credit word only received clear',
    () => caught(
      other,
      'RM 25.00 credited to your wallet.',
      '25.00',
      TransactionType.receive,
      true,
    ),
  );

  test(
    'generic rule both words unclear',
    () => caught(
      other,
      'Refund for payment RM 9.90 is on the way.',
      '9.90',
      TransactionType.withdraw,
      false,
    ),
  );

  test(
    'known app no amount no match',
    () => expect(
      PaymentRules.match(maybank, 'Your statement is ready.'),
      isA<NoMatch>(),
    ),
  );

  test(
    'unknown app no amount no match',
    () => expect(
      PaymentRules.match(other, 'Your statement is ready'),
      isA<NoMatch>(),
    ),
  );

  test(
    'maybank QR payment dotted name',
    () => known(
      maybank,
      'Successful payment of RM 9.80 to CONTOHKITCHENSDN.BHD.. REF: QR123456.',
      '9.80',
      'CONTOHKITCHENSDN.BHD',
      TransactionType.withdraw,
    ),
  );

  test(
    'maybank M2U paid Sdn Bhd',
    () => known(
      maybank,
      'M2U: You have successfully paid RM12.00 to CONTOH SDN. BHD.',
      '12.00',
      'CONTOH SDN. BHD',
      TransactionType.withdraw,
    ),
  );

  test(
    'tng paid abbreviations',
    () => known(
      tng,
      'You have paid RM7.50 to M.R. CONTOH (M) S/B.',
      '7.50',
      'M.R. CONTOH (M) S/B',
      TransactionType.withdraw,
    ),
  );

  test(
    'tng paid then balance sentence',
    () => known(
      tng,
      'You have paid RM7.50 to CAFE CONTOH. Balance RM20.00.',
      '7.50',
      'CAFE CONTOH',
      TransactionType.withdraw,
    ),
  );

  test(
    'maybank QR payment then transaction id',
    () => known(
      maybank,
      'Successful payment of RM 9.80 to KEDAI CONTOH. Transaction ID 123456.',
      '9.80',
      'KEDAI CONTOH',
      TransactionType.withdraw,
    ),
  );

  test(
    'tng received sender first',
    () => known(
      tng,
      'ALI BIN ABU has transferred RM 10.00 to you. Tap here to check the transaction details.',
      '10.00',
      'ALI BIN ABU',
      TransactionType.receive,
    ),
  );

  test(
    'maybank transfer to ewallet account',
    () => known(
      maybank,
      "You've transferred RM 10.00 to SITI AMINAH's TOUCH N GO eWALLET account ending ****1234. REF: 123456789M",
      '10.00',
      "SITI AMINAH's TOUCH N GO eWALLET",
      TransactionType.withdraw,
    ),
  );

  test('unknown app generic match', () {
    final match = PaymentRules.match(
      other,
      'You spent RM 14.23 at Contoh Mart',
    ) as Matched;
    expect(match.format, CaptureFormat.unknown);
    expect(match.expense.amount, Decimal.parse('14.23'));
    expect(match.expense.merchant, 'Contoh Mart');
    expect(match.expense.transactionType, TransactionType.withdraw);
    expect(match.expense.directionClear, true);
  });

  test('preselect packages are maybank and tng only', () {
    expect(PaymentRules.preselectPackages, {maybank, tng});
    expect(PaymentRules.knownPackages.contains(wallet), true);
  });

  test('rule words match in any letter case', () {
    known(
      maybank,
      'You have SPENT RM 5.00 AT Café Sdn. Bhd. View details',
      '5.00',
      'Café Sdn. Bhd',
      TransactionType.withdraw,
    );
  });
}
