import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/top_up.dart';

void main() {
  test('wallet reload and top-up texts are top-ups', () {
    for (final t in [
      "Your money is in! RM20.00 has been reloaded to your Touch 'n Go eWallet balance. Reference No. 2026111500000000000000000000000000001",
      'Top up of RM50.00 successful.',
      'You topped up RM10.00 via FPX.',
      'Top-Up RM30.00 received',
      'RELOAD RM5.00 OK',
    ]) {
      expect(looksLikeTopUp(t), isTrue, reason: t);
    }
  });

  test('payments and words that only contain the letters are not top-ups', () {
    for (final t in [
      "You've just spent RM 18.80 at GRAB-EC with your Maybank Debit Card Visa ending 3729.",
      'Paid RM12.00 to Reloadable Store',
      'Payment of RM8.00 to UPLOAD CAFE successful.',
      'Stop update reminders',
    ]) {
      expect(looksLikeTopUp(t), isFalse, reason: t);
    }
  });
}
