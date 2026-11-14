/// Rules for when the app checks for a new release.
abstract final class UpdateSchedule {
  static const checkIntervalMs = 86400000;

  /// Never checks when Online features are off. A manual check runs at once.
  /// An automatic check runs after one day, or when the clock went back.
  static bool shouldCheck({
    required bool online,
    required int lastCheckMs,
    required int nowMs,
    required bool manual,
  }) =>
      online &&
      (manual || nowMs < lastCheckMs || nowMs - lastCheckMs >= checkIntervalMs);
}
