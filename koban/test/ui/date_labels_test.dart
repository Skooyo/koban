import 'package:flutter_test/flutter_test.dart';
import 'package:koban/ui/date_labels.dart';

int at(int y, int m, int d, [int h = 12, int min = 0]) =>
    DateTime(y, m, d, h, min).millisecondsSinceEpoch;

void main() {
  final now = DateTime(2026, 11, 13, 12);

  test('dates near now say Today and Yesterday', () {
    expect(dateLabel(at(2026, 11, 13, 8), now), 'Today');
    expect(dateLabel(at(2026, 11, 12, 23, 59), now), 'Yesterday');
    expect(dateLabel(at(2026, 11, 11), now), 'Wed, 11 Nov');
  });

  test('a day header of another year shows the year', () {
    expect(dayHeaderLabel(at(2025, 11, 13), now), 'Thu, 13 Nov 2025');
    expect(dayHeaderLabel(at(2026, 11, 13), now), 'Today');
    expect(dayHeaderLabel(at(2026, 11, 12), now), 'Yesterday');
    expect(dayHeaderLabel(at(2026, 11, 11), now), 'Wed, 11 Nov');
  });

  test('a date and time label has the day, the date and the time', () {
    expect(dateTimeLabel(at(2026, 11, 11, 20, 15)), 'Wed, 11 Nov, 20:15');
  });
}
