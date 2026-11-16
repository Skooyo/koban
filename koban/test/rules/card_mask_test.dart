import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/card_mask.dart';

void main() {
  test(
    'a run of 4 or more digits after ending, ending with or no. keeps 2',
    () {
      expect(
        maskCardDigits('Visa ending 1234 was used'),
        'Visa ending ••34 was used',
      );
      expect(
        maskCardDigits('card ending with 567890.'),
        'card ending with ••90.',
      );
      expect(
        maskCardDigits('Account no. 00112233 debited'),
        'Account no. ••33 debited',
      );
      expect(maskCardDigits('Card Ending 4321'), 'Card Ending ••21');
    },
  );

  test('other digits stay', () {
    expect(
      maskCardDigits('ending 123 and RM 1500.00, REF 9876543'),
      'ending 123 and RM 1500.00, REF 9876543',
    );
  });
}
