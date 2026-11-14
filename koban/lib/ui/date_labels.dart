import 'package:intl/intl.dart';

DateTime _local(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String? _todayOrYesterday(DateTime day, DateTime now) {
  if (_sameDay(day, now)) return 'Today';
  if (_sameDay(day, DateTime(now.year, now.month, now.day - 1))) {
    return 'Yesterday';
  }
  return null;
}

/// "Today", "Yesterday", or "Mon, 12 Oct".
String dateLabel(int ms, DateTime now) {
  final day = _local(ms);
  return _todayOrYesterday(day, now) ??
      DateFormat('EEE, d MMM', 'en_US').format(day);
}

/// "Wed, 11 Nov, 20:15".
String dateTimeLabel(int ms) =>
    DateFormat('EEE, d MMM, HH:mm', 'en_US').format(_local(ms));

/// The heading of one day in a list. It adds the year when the year is not this year.
String dayHeaderLabel(int ms, DateTime now) {
  final day = _local(ms);
  return _todayOrYesterday(day, now) ??
      DateFormat(
        day.year == now.year ? 'EEE, d MMM' : 'EEE, d MMM yyyy',
        'en_US',
      ).format(day);
}
