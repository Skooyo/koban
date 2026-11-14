import '../data/legacy_import.dart' show describeError;
import '../data/pending_payment_repository.dart';
import '../rules/amount_formatter.dart';
import '../rules/payment_rules.dart';
import 'capture_host.dart';
import 'payment_apps.dart';

/// Reads the native queue, parses each row and saves a card.
/// A row leaves the queue only after its card is saved or a final skip is decided.
class CaptureWorker {
  CaptureWorker({
    required this._host,
    required this._payments,
    required this._paymentApps,
  });

  final CaptureHost _host;
  final PendingPaymentRepository _payments;
  final PaymentApps _paymentApps;

  Future<void>? _running;
  bool _again = false;

  /// Handle the queue. A call during a run adds no second run: the run goes on.
  Future<void> drain() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    return _running = _run().whenComplete(() => _running = null);
  }

  Future<void> _run() async {
    final apps = await _paymentApps.load();
    var afterId = 0;
    do {
      _again = false;
      while (true) {
        final batch = await _host.takeQueue(afterId);
        if (batch.isEmpty) break;
        afterId = batch.last.id;
        for (final row in batch) {
          await _handle(row, apps);
        }
      }
    } while (_again);
  }

  Future<void> _handle(QueuedNotification row, Set<String> apps) async {
    try {
      if (!apps.contains(row.packageName)) {
        await _host.finish(
          row,
          NotificationDisposition.skippedAllowlist,
          'Package not on allowlist',
        );
        return;
      }
      final match = PaymentRules.match(row.packageName, row.text);
      if (match is! Matched) {
        await _host.finish(
          row,
          NotificationDisposition.skippedNoRule,
          'No rule matched this text',
        );
        return;
      }
      final parsed = match.expense;
      final id = await _payments.capture(
        parsed: parsed,
        format: match.format,
        rawText: row.text,
        sourcePackage: row.packageName,
        notificationPostTime: row.postTime,
        notificationKey: row.notificationKey,
      );
      if (id == null) {
        await _host.finish(
          row,
          NotificationDisposition.skippedDuplicate,
          'Duplicate within dedup window',
        );
        return;
      }
      await _host.finish(
        row,
        NotificationDisposition.waiting,
        '${parsed.merchant ?? 'Unknown'} · RM ${AmountFormatter.formatDisplay(parsed.amount)}',
      );
    } catch (e) {
      // The row stays in the queue. The next wake tries it again.
      try {
        await _host.updateLog(
          row.logId,
          NotificationDisposition.skippedError,
          describeError(e),
        );
      } catch (_) {}
    }
  }
}
