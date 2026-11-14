import 'dart:async';

import 'package:koban/capture/capture_host.dart';

/// A capture host in memory. Tests use it in place of the native channel.
class FakeCaptureHost implements CaptureHost {
  /// The rows that wait. `finish` removes a row.
  final List<QueuedNotification> queue = [];
  final List<(int, String, String)> finished = [];
  final List<(String, String, String)> logUpdates = [];
  final List<(String, String, String, String)> appended = [];
  Set<String>? paymentApps;
  bool gateHeld = false;

  /// Runs each time `takeQueue` is called, after it picked its rows and before it answers.
  /// Rows that it adds show in the next call.
  void Function(int afterId)? onTake;

  Future<void> Function()? _drainHandler;
  final List<Completer<void>> _gateWaiters = [];

  @override
  Future<List<QueuedNotification>> takeQueue(int afterId) async {
    final rows = [
      for (final r in queue)
        if (r.id > afterId) r,
    ];
    onTake?.call(afterId);
    return rows;
  }

  @override
  Future<void> finish(
    QueuedNotification row,
    NotificationDisposition d,
    String detail,
  ) async {
    queue.removeWhere((r) => r.id == row.id);
    finished.add((row.id, d.dbName, detail));
  }

  /// When set, `updateLog` records the call and then throws it.
  Object? updateLogError;

  @override
  Future<void> updateLog(
    String logId,
    NotificationDisposition d,
    String detail,
  ) async {
    logUpdates.add((logId, d.dbName, detail));
    final error = updateLogError;
    if (error != null) throw error;
  }

  @override
  Future<void> appendLog(
    String title,
    String body,
    NotificationDisposition d,
    String detail,
  ) async => appended.add((title, body, d.dbName, detail));

  @override
  Future<void> setPaymentApps(Set<String> apps) async => paymentApps = apps;

  @override
  Future<void> acquireImportGate() async {
    if (!gateHeld) {
      gateHeld = true;
      return;
    }
    final waiter = Completer<void>();
    _gateWaiters.add(waiter);
    await waiter.future;
  }

  @override
  Future<void> releaseImportGate() async {
    if (_gateWaiters.isEmpty) {
      gateHeld = false;
    } else {
      _gateWaiters.removeAt(0).complete();
    }
  }

  @override
  void onDrain(Future<void> Function() handler) => _drainHandler = handler;

  /// Act as a native `drain` call.
  Future<void> triggerDrain() => _drainHandler!();
}
