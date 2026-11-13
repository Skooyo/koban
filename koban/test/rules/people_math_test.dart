import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/people_math.dart';

Decimal m(String s) => Decimal.parse(s);

void main() {
  test('net subtracts what I owe', () {
    expect(PeopleMath.net([m('23.31')], [m('18.00')]), m('5.31'));
  });

  test('balance pays you when positive', () {
    expect(PeopleMath.balance([m('23.31')], [m('18.00')]), PaysYou(m('5.31')));
  });

  test('balance you pay when negative', () {
    expect(PeopleMath.balance([], [m('18.00')]), YouPay(m('18.00')));
  });

  test('status even when net zero with open items', () {
    expect(PeopleMath.balance([m('10.00')], [m('10.00')]), const Even());
  });

  test('status all paid when nothing open', () {
    expect(PeopleMath.balance([], []), const AllPaid());
  });

  test('headline names who pays', () {
    expect(
      PeopleMath.headline('Jun Wei', PaysYou(m('5.31'))),
      'Jun Wei pays you RM 5.31',
    );
    expect(
      PeopleMath.headline('Jun Wei', YouPay(m('18.00'))),
      'You pay Jun Wei RM 18.00',
    );
  });

  test('status line no QR only when all paid', () {
    expect(
      PeopleMath.statusLine('Daniel', const AllPaid(), hasQr: false),
      'No QR saved yet',
    );
    expect(
      PeopleMath.statusLine('Aisyah', const AllPaid(), hasQr: true),
      'All paid',
    );
    expect(
      PeopleMath.statusLine('Jun Wei', YouPay(m('18.00')), hasQr: false),
      'You pay RM 18.00',
    );
  });

  test('group orders you owe first', () {
    expect(PeopleMath.group(YouPay(m('1.00'))), PeopleGroup.youOwe);
    expect(PeopleMath.group(PaysYou(m('1.00'))), PeopleGroup.owesYou);
    expect(PeopleMath.group(const Even()), PeopleGroup.others);
  });

  test('normalized name matches case and spaces', () {
    expect(
      PeopleMath.normalizedName('  Jun   Wei '),
      PeopleMath.normalizedName('jun wei'),
    );
  });

  test('settle match single candidate', () {
    expect(
      PeopleMath.settleMatch(m('5.31'), 'SOMEONE', [
        SettleCandidate('p1', 'Jun Wei', m('5.31')),
      ]),
      'p1',
    );
  });

  test('settle match sender breaks tie', () {
    expect(
      PeopleMath.settleMatch(m('5.31'), 'PRIYA DEVI', [
        SettleCandidate('p1', 'Jun Wei', m('5.31')),
        SettleCandidate('p2', 'Priya', m('5.31')),
      ]),
      'p2',
    );
  });

  test('settle match ambiguous without sender returns null', () {
    expect(
      PeopleMath.settleMatch(m('5.31'), null, [
        SettleCandidate('p1', 'Jun Wei', m('5.31')),
        SettleCandidate('p2', 'Priya', m('5.31')),
      ]),
      isNull,
    );
  });

  test('settle match ignores people I owe', () {
    expect(
      PeopleMath.settleMatch(m('5.31'), null, [
        SettleCandidate('p1', 'Jun Wei', m('-5.31')),
      ]),
      isNull,
    );
  });

  test('normalized name treats a non-breaking space like a space', () {
    expect(
      PeopleMath.normalizedName('Ali\u00a0Bin'),
      PeopleMath.normalizedName('Ali Bin'),
    );
  });
}
