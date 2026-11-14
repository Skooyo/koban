import 'dart:async';
import 'dart:developer' as developer;

import 'database.dart';

/// Finds writes of the capture isolate, which has its own connection.
/// Drift sees only the writes of its own connection, so on a change this
/// class tells the Drift streams of this connection to read again.
// ponytail: polls every 2 s while the app is in front; upgrade: a native call from the capture engine after each card.
class ExternalWrites {
  ExternalWrites(this._db, {this._every = const Duration(seconds: 2)});

  final KobanDatabase _db;
  final Duration _every;
  Timer? _timer;
  bool _checking = false;

  /// The last `data_version`. It stays when the polls stop, so a write
  /// while the app is not in front shows at the next start.
  int? _last;

  /// Checks at once, then every 2 s. A second call does nothing.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(_every, (_) => _poll());
    _poll();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Returns true when another connection wrote since the last check, and
  /// then marks the tables of the cards and the payments as changed.
  /// The first check has nothing to compare, so it counts as a change.
  Future<bool> checkNow() async {
    final row = await _db.customSelect('PRAGMA data_version').getSingle();
    final version = row.read<int>('data_version');
    final changed = version != _last;
    _last = version;
    if (changed) _db.markTablesUpdated({_db.pendingPayments, _db.expenses});
    return changed;
  }

  Future<void> _poll() async {
    if (_checking) return;
    _checking = true;
    try {
      await checkNow();
    } catch (e, s) {
      developer.log(
        'Check for writes of the capture engine failed',
        name: 'ExternalWrites',
        error: e,
        stackTrace: s,
      );
    } finally {
      _checking = false;
    }
  }
}
