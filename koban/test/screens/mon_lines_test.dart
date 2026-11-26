import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/summaries.dart';
import 'package:koban/screens/activity/activity_mon.dart';
import 'package:koban/screens/home/home_mon.dart';
import 'package:koban/theme/mon.dart';

Decimal d(String v) => Decimal.parse(v);

MonSay home({
  bool trackingOn = true,
  bool listensToNoApp = false,
  int waitingCount = 0,
  bool hasAnyPayment = true,
  String week = '0',
  String lastWeek = '0',
}) => homeMon(
  trackingOn: trackingOn,
  listensToNoApp: listensToNoApp,
  waitingCount: waitingCount,
  hasAnyPayment: hasAnyPayment,
  weekSpent: d(week),
  lastWeekSoFar: d(lastWeek),
);

CategoryBreakdown cat(String id, String name, String total) =>
    CategoryBreakdown(
      categoryId: id,
      name: name,
      colorHex: '#000000',
      total: d(total),
      fraction: 0,
    );

void main() {
  test('the Home title is the date in Malaysia time', () {
    expect(dateTitle(DateTime.utc(2026, 11, 26, 15, 59)), 'Thu, 26 Nov');
    // 16:00 UTC is midnight in Malaysia.
    expect(dateTitle(DateTime.utc(2026, 11, 26, 16)), 'Fri, 27 Nov');
  });

  test('Home Mon puts a problem before good news', () {
    final off = home(
      trackingOn: false,
      waitingCount: 3,
      week: '1',
      lastWeek: '9',
    );
    expect(off.face, MonFace.worry);
    expect(off.line, 'I cannot see your payments.');
    final none = home(listensToNoApp: true, waitingCount: 3);
    expect(none.face, MonFace.worry);
    expect(none.line, 'I listen to no app.');
  });

  test('Home Mon says payments are waiting, in the singular too', () {
    expect(home(waitingCount: 1).line, 'A payment is waiting.');
    final many = home(waitingCount: 3, week: '1', lastWeek: '9');
    expect(many.face, MonFace.idle);
    expect(many.line, 'Payments are waiting.');
  });

  test('Home Mon waits for the first payment', () {
    final first = home(hasAnyPayment: false);
    expect(first.face, MonFace.idle);
    expect(first.line, 'Nothing here yet.');
  });

  test('Home Mon compares this week with last week up to the same day', () {
    final less = home(week: '40.00', lastWeek: '90.00');
    expect(less.face, MonFace.happy);
    expect(less.line, 'You spent less than last week.');
    final more = home(week: '120.00', lastWeek: '90.00');
    expect(more.face, MonFace.idle);
    expect(more.line, 'More than last week so far.');
    expect(home(week: '90.00', lastWeek: '90.00').line, 'A quiet week so far.');
  });

  test('Home Mon does not cheer when last week had no spending', () {
    final quiet = home(week: '0', lastWeek: '0');
    expect(quiet.face, MonFace.idle);
    expect(quiet.line, 'A quiet week so far.');
    expect(home(week: '5.00', lastWeek: '0').line, 'A quiet week so far.');
  });

  test('Activity Mon names the top category and its share', () {
    final say = activityMon(
      showAll: false,
      searching: false,
      filtered: false,
      monthLabel: 'November 2026',
      breakdown: [
        cat('transport', 'Transport', '25.00'),
        cat('food', 'Food & Dining', '75.00'),
        cat('bills', 'Bills', '0'),
      ],
    );
    expect(say.line, 'Food & Dining leads.');
    expect(say.detail, 'It is 75% of what you spent.');
  });

  test('Activity Mon follows the search, the All view and an empty month', () {
    MonSay pick({
      bool showAll = false,
      bool searching = false,
      bool filtered = false,
      List<CategoryBreakdown> breakdown = const [],
    }) => activityMon(
      showAll: showAll,
      searching: searching,
      filtered: filtered,
      monthLabel: 'October 2026',
      breakdown: breakdown,
    );
    expect(pick(searching: true).line, 'Digging through your payments.');
    expect(pick(filtered: true).line, 'Digging through your payments.');
    expect(pick(showAll: true).line, 'Everything I have counted.');
    expect(pick().line, 'Nothing in October 2026.');
  });
}
