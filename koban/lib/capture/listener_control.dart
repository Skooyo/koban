import 'package:flutter/services.dart';

import 'capture_host.dart';

/// The result of a reconnect. Same names as the Kotlin `ReconnectResult`.
enum ReconnectResult {
  accessNotGranted('ACCESS_NOT_GRANTED'),
  attempted('ATTEMPTED'),
  throttled('THROTTLED'),
  failed('FAILED');

  const ReconnectResult(this.dbName);

  /// The Kotlin enum constant name.
  final String dbName;

  static ReconnectResult fromDbName(String name) => values.firstWhere(
    (e) => e.dbName == name,
    orElse: () => throw ArgumentError('Unknown ReconnectResult: $name'),
  );
}

/// The settings page that opened. Same names as the Kotlin `OemBatteryHelper.OpenResult`.
enum BackgroundSettingsResult {
  xiaomiAutostart('XIAOMI_AUTOSTART'),
  xiaomiOther('XIAOMI_OTHER'),
  genericBattery('GENERIC_BATTERY');

  const BackgroundSettingsResult(this.dbName);

  /// The Kotlin enum constant name.
  final String dbName;

  static BackgroundSettingsResult fromDbName(String name) => values.firstWhere(
    (e) => e.dbName == name,
    orElse: () => throw ArgumentError('Unknown BackgroundSettingsResult: $name'),
  );
}

/// The listener event of a log row. Same names as the Kotlin `NotificationCaptureEvent`.
enum CaptureEvent {
  posted('POSTED'),
  removed('REMOVED'),
  activeSnapshot('ACTIVE_SNAPSHOT');

  const CaptureEvent(this.dbName);

  /// The Kotlin enum constant name.
  final String dbName;

  static CaptureEvent fromDbName(String name) => values.firstWhere(
    (e) => e.dbName == name,
    orElse: () => throw ArgumentError('Unknown CaptureEvent: $name'),
  );
}

/// One row of the native notification log.
class LoggedNotification {
  const LoggedNotification({
    required this.id,
    required this.packageName,
    required this.title,
    required this.body,
    required this.postTime,
    required this.capturedAt,
    required this.event,
    required this.disposition,
    required this.detail,
  });

  factory LoggedNotification.fromMap(Map<Object?, Object?> m) =>
      LoggedNotification(
        id: m['id']! as String,
        packageName: m['packageName']! as String,
        title: m['title'] as String?,
        body: m['body']! as String,
        postTime: (m['postTime']! as num).toInt(),
        capturedAt: (m['capturedAt']! as num).toInt(),
        event: CaptureEvent.fromDbName(m['event']! as String),
        disposition: NotificationDisposition.fromDbName(
          m['disposition']! as String,
        ),
        detail: m['detail'] as String?,
      );

  final String id;
  final String packageName;
  final String? title;
  final String body;
  final int postTime;
  final int capturedAt;
  final CaptureEvent event;
  final NotificationDisposition disposition;
  final String? detail;
}

/// The connection state of the native listener.
class ListenerState {
  const ListenerState({
    required this.isConnected,
    required this.lastConnectedAt,
    required this.lastDisconnectedAt,
    required this.totalCaptured,
  });

  factory ListenerState.fromMap(Map<Object?, Object?> m) => ListenerState(
    isConnected: m['isConnected']! as bool,
    lastConnectedAt: (m['lastConnectedAt'] as num?)?.toInt(),
    lastDisconnectedAt: (m['lastDisconnectedAt'] as num?)?.toInt(),
    totalCaptured: (m['totalCaptured']! as num).toInt(),
  );

  final bool isConnected;
  final int? lastConnectedAt;
  final int? lastDisconnectedAt;
  final int totalCaptured;
}

/// Controls the native notification listener. One method for each native method.
class ListenerControl {
  ListenerControl() : _channel = const MethodChannel(channelName);

  static const channelName = 'io.github.skooyo.koban/listener';

  final MethodChannel _channel;

  Future<bool> isAccessGranted() async =>
      (await _channel.invokeMethod<bool>('isAccessGranted'))!;

  Future<bool> isConnected() async =>
      (await _channel.invokeMethod<bool>('isConnected'))!;

  /// Start the keep-alive service, the watchdog and a reconnect burst.
  /// Without access, stop them.
  Future<void> ensureActive() => _channel.invokeMethod<void>('ensureActive');

  Future<ReconnectResult> reconnect() async => ReconnectResult.fromDbName(
    (await _channel.invokeMethod<String>('reconnect'))!,
  );

  Future<void> openAccessSettings() =>
      _channel.invokeMethod<void>('openAccessSettings');

  Future<bool> isBatteryOptimizationIgnored() async =>
      (await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored'))!;

  Future<void> openBatteryOptimizationSettings() =>
      _channel.invokeMethod<void>('openBatteryOptimizationSettings');

  Future<bool> isXiaomiFamily() async =>
      (await _channel.invokeMethod<bool>('isXiaomiFamily'))!;

  Future<BackgroundSettingsResult> openBackgroundSettings() async =>
      BackgroundSettingsResult.fromDbName(
        (await _channel.invokeMethod<String>('openBackgroundSettings'))!,
      );

  /// The notification log, newest first (the native order).
  Future<List<LoggedNotification>> recentNotifications() async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'recentNotifications',
    );
    return [for (final r in rows ?? const []) LoggedNotification.fromMap(r)];
  }

  Future<ListenerState> listenerState() async => ListenerState.fromMap(
    (await _channel.invokeMapMethod<Object?, Object?>('listenerState'))!,
  );

  Future<void> clearLog() => _channel.invokeMethod<void>('clearLog');

  /// Read the notifications that show now. False when the listener is not connected.
  Future<bool> snapshotActive() async =>
      (await _channel.invokeMethod<bool>('snapshotActive'))!;
}
