import 'package:flutter/services.dart';

/// What happened to one captured notification. Same names as the Kotlin enum.
enum NotificationDisposition {
  pending('PENDING'),
  waiting('WAITING'),
  skippedAllowlist('SKIPPED_ALLOWLIST'),
  skippedNoRule('SKIPPED_NO_RULE'),
  skippedDuplicate('SKIPPED_DUPLICATE'),
  skippedGroupSummary('SKIPPED_GROUP_SUMMARY'),
  skippedEmpty('SKIPPED_EMPTY'),
  skippedError('SKIPPED_ERROR'),
  infoOnly('INFO_ONLY');

  const NotificationDisposition(this.dbName);

  /// The name that native code uses (the Kotlin enum constant name).
  final String dbName;

  static NotificationDisposition fromDbName(String name) => values.firstWhere(
    (e) => e.dbName == name,
    orElse: () => throw ArgumentError('Unknown NotificationDisposition: $name'),
  );
}

/// One row of the native capture queue.
class QueuedNotification {
  const QueuedNotification({
    required this.id,
    required this.logId,
    required this.packageName,
    required this.title,
    required this.text,
    required this.postTime,
    required this.notificationKey,
  });

  factory QueuedNotification.fromMap(Map<Object?, Object?> m) =>
      QueuedNotification(
        id: (m['id']! as num).toInt(),
        logId: m['logId']! as String,
        packageName: m['packageName']! as String,
        title: m['title'] as String?,
        text: m['text']! as String,
        postTime: (m['postTime']! as num).toInt(),
        notificationKey: m['notificationKey'] as String?,
      );

  final int id;
  final String logId;
  final String packageName;
  final String? title;
  final String text;
  final int postTime;
  final String? notificationKey;
}

/// The Dart side of the native capture queue.
abstract interface class CaptureHost {
  /// The queue rows with an id above [afterId], oldest first.
  Future<List<QueuedNotification>> takeQueue(int afterId);

  /// Remove [row] from the queue and set its log entry.
  Future<void> finish(
    QueuedNotification row,
    NotificationDisposition d,
    String detail,
  );

  /// Set a log entry. The row stays in the queue.
  Future<void> updateLog(
    String logId,
    NotificationDisposition d,
    String detail,
  );

  /// Add a new log entry.
  Future<void> appendLog(
    String title,
    String body,
    NotificationDisposition d,
    String detail,
  );

  /// Give the native listener the chosen payment apps.
  Future<void> setPaymentApps(Set<String> apps);

  /// Wait until no other engine runs the legacy import.
  Future<void> acquireImportGate();

  Future<void> releaseImportGate();

  /// Set the function that native code calls when the queue has new rows.
  void onDrain(Future<void> Function() handler);
}

/// [CaptureHost] on the platform channel.
class ChannelCaptureHost implements CaptureHost {
  ChannelCaptureHost() : _channel = const MethodChannel(channelName);

  static const channelName = 'io.github.skooyo.koban/capture';

  final MethodChannel _channel;

  @override
  Future<List<QueuedNotification>> takeQueue(int afterId) async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'takeQueue',
      {'afterId': afterId},
    );
    return [for (final r in rows ?? const []) QueuedNotification.fromMap(r)];
  }

  @override
  Future<void> finish(
    QueuedNotification row,
    NotificationDisposition d,
    String detail,
  ) => _channel.invokeMethod<void>('finish', {
    'id': row.id,
    'logId': row.logId,
    'disposition': d.dbName,
    'detail': detail,
  });

  @override
  Future<void> updateLog(
    String logId,
    NotificationDisposition d,
    String detail,
  ) => _channel.invokeMethod<void>('updateLog', {
    'logId': logId,
    'disposition': d.dbName,
    'detail': detail,
  });

  @override
  Future<void> appendLog(
    String title,
    String body,
    NotificationDisposition d,
    String detail,
  ) => _channel.invokeMethod<void>('appendLog', {
    'title': title,
    'body': body,
    'disposition': d.dbName,
    'detail': detail,
  });

  @override
  Future<void> setPaymentApps(Set<String> apps) =>
      _channel.invokeMethod<void>('setPaymentApps', {
        'apps': apps.toList()..sort(),
      });

  @override
  Future<void> acquireImportGate() =>
      _channel.invokeMethod<void>('acquireImportGate');

  @override
  Future<void> releaseImportGate() =>
      _channel.invokeMethod<void>('releaseImportGate');

  @override
  void onDrain(Future<void> Function() handler) =>
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'drain') {
          await handler();
          return null;
        }
        throw MissingPluginException();
      });
}
