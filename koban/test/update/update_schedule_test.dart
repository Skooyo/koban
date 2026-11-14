import 'package:flutter_test/flutter_test.dart';
import 'package:koban/update/update_schedule.dart';

void main() {
  test('with Online features off it never checks', () {
    expect(
      UpdateSchedule.shouldCheck(
        online: false,
        lastCheckMs: 0,
        nowMs: 100000000,
        manual: true,
      ),
      false,
    );
  });

  test('a manual check runs at once', () {
    expect(
      UpdateSchedule.shouldCheck(
        online: true,
        lastCheckMs: 99999999,
        nowMs: 100000000,
        manual: true,
      ),
      true,
    );
  });

  test('an automatic check waits one day', () {
    expect(
      UpdateSchedule.shouldCheck(
        online: true,
        lastCheckMs: 100000000,
        nowMs: 100000000 + 86399999,
        manual: false,
      ),
      false,
    );
  });

  test('an automatic check runs after one day', () {
    expect(
      UpdateSchedule.shouldCheck(
        online: true,
        lastCheckMs: 100000000,
        nowMs: 100000000 + 86400000,
        manual: false,
      ),
      true,
    );
  });

  test('a clock set back checks', () {
    expect(
      UpdateSchedule.shouldCheck(
        online: true,
        lastCheckMs: 200000000,
        nowMs: 100000000,
        manual: false,
      ),
      true,
    );
  });
}
