import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../capture/capture_host.dart';
import '../../capture/listener_control.dart';

/// Which rows of the log show. Same names as the 0.1.1 `NotificationDebugFilter`.
enum LogFilter { all, postedOnly, waiting, skipped }

/// The rows that [f] lets through. A skipped row is one that is not waiting, pending or info only.
List<LoggedNotification> filterLog(
  List<LoggedNotification> rows,
  LogFilter f,
) => switch (f) {
  LogFilter.all => rows,
  LogFilter.postedOnly => [
    for (final n in rows)
      if (n.event == CaptureEvent.posted) n,
  ],
  LogFilter.waiting => [
    for (final n in rows)
      if (n.disposition == NotificationDisposition.waiting) n,
  ],
  LogFilter.skipped => [
    for (final n in rows)
      if (n.disposition != NotificationDisposition.waiting &&
          n.disposition != NotificationDisposition.pending &&
          n.disposition != NotificationDisposition.infoOnly)
        n,
  ],
};

/// The state of the notification log: the status, the rows and the filter.
class NotificationLogViewModel extends ChangeNotifier {
  /// [poll] is the time between two reads of the log while the screen is open.
  /// [reconnectWait] is the time between a reconnect and its result. 0.1.1 waits 65 s.
  NotificationLogViewModel(
    this._s, {
    this.poll = const Duration(seconds: 2),
    this.reconnectWait = const Duration(seconds: 65),
  }) {
    resumePolling();
  }

  final AppServices _s;
  final Duration poll;
  final Duration reconnectWait;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  var _disposed = false;
  var _reconnectPending = false;
  var _reading = false;
  var _readAgain = false;

  /// True after a failed read, until a read works. Only the first failure of a run is logged.
  var _readFailing = false;

  /// Counts the changes of the native log (clear, snapshot). A read that began in an older generation is dropped.
  var _generation = 0;
  final Set<String> _marking = {};

  /// The rows that got a card while this screen is open. The log can show them as
  /// skipped a little longer, and a forced card skips the duplicate check.
  final Set<String> _marked = {};

  bool _isAccessGranted = false;
  bool _isConnected = false;
  ListenerState _listenerState = const ListenerState(
    isConnected: false,
    lastConnectedAt: null,
    lastDisconnectedAt: null,
    totalCaptured: 0,
  );
  List<LoggedNotification> _rows = const [];
  var _filter = LogFilter.all;
  String? _message;

  bool get isAccessGranted => _isAccessGranted;
  bool get isConnected => _isConnected;
  ListenerState get listenerState => _listenerState;

  /// All rows of the log, before the filter.
  List<LoggedNotification> get rows => _rows;

  /// The rows that the filter lets through.
  List<LoggedNotification> get shown => filterLog(_rows, _filter);
  LogFilter get filter => _filter;
  String? get message => _message;

  /// True when Add as payment already made a card for the row [id].
  bool isMarked(String id) => _marked.contains(id);

  /// Reads the log and the listener state at a set time while the screen is open.
  /// ponytail: a poll costs three channel calls each 2 s. Upgrade path: a native event
  /// for each change, when milestone 6 needs it.
  void resumePolling() {
    _pollTimer?.cancel();
    if (_disposed) return;
    _pollTimer = Timer.periodic(poll, (_) => _readLog());
  }

  /// Stops the poll. The screen calls it when it is hidden.
  void pausePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Reads the log. A read that is already in flight runs once more after it when [again] is true.
  Future<void> _readLog({bool again = false}) async {
    if (_reading) {
      if (again) _readAgain = true;
      return;
    }
    _reading = true;
    try {
      do {
        _readAgain = false;
        final generation = _generation;
        final l = _s.listener;
        final rows = await l.recentNotifications();
        final state = await l.listenerState();
        final connected = await l.isConnected();
        if (_disposed) return;
        if (generation != _generation) continue;
        _rows = rows;
        _listenerState = state;
        _isConnected = connected;
        _readFailing = false;
        notifyListeners();
      } while (_readAgain);
    } catch (e, s) {
      if (!_readFailing) _log('Log read failed', e, s);
      _readFailing = true;
    } finally {
      _reading = false;
    }
  }

  /// Reads the phone state and the log again, and starts the listener.
  Future<void> refresh() async {
    try {
      final l = _s.listener;
      final granted = await l.isAccessGranted();
      await l.ensureActive();
      if (_disposed) return;
      _isAccessGranted = granted;
      _message = null;
      notifyListeners();
    } catch (e, s) {
      _log('Refresh failed', e, s);
    }
    await _readLog();
  }

  static void _log(String message, Object e, StackTrace s) =>
      developer.log(message, name: 'NotificationLog', error: e, stackTrace: s);

  void _setMessage(String? m) {
    if (_disposed) return;
    _message = m;
    notifyListeners();
  }

  /// Asks the native listener to reconnect. After a good attempt, the result shows [reconnectWait] later.
  /// A tap while an attempt waits does nothing.
  Future<void> reconnect() async {
    if (_reconnectPending) return;
    _reconnectPending = true;
    _setMessage('Reconnecting…');
    try {
      final result = await _s.listener.reconnect();
      switch (result) {
        case ReconnectResult.accessNotGranted:
          _setMessage(
            'Notification access was removed — re-enable in system settings.',
          );
        case ReconnectResult.throttled:
          _setMessage('Reconnect already attempted recently.');
        case ReconnectResult.failed:
          _setMessage('Reconnect failed — open notification access settings.');
        case ReconnectResult.attempted:
          if (_disposed) return;
          _reconnectTimer = Timer(reconnectWait, _showReconnectResult);
          return;
      }
    } catch (e, s) {
      debugPrint('Reconnect failed: $e\n$s');
      _setMessage('Reconnect failed — open notification access settings.');
    }
    _reconnectPending = false;
  }

  Future<void> _showReconnectResult() async {
    try {
      final connected = await _s.listener.isConnected();
      _setMessage(
        connected ? 'Listener connected.' : 'Still disconnected — use the alert notification or open notification access settings.',
      );
    } catch (e, s) {
      debugPrint('Reconnect check failed: $e\n$s');
    } finally {
      _reconnectPending = false;
    }
  }

  void setFilter(LogFilter f) {
    _filter = f;
    notifyListeners();
  }

  Future<void> clearLog() async {
    await _s.listener.clearLog();
    _generation++;
    _setMessage('Log cleared');
    await _readLog(again: true);
  }

  /// Reads the notifications that show now and says if it worked.
  Future<void> snapshot() async {
    final ok = await _s.listener.snapshotActive();
    _generation++;
    _setMessage(
      ok ? 'Snapshotted active status-bar notifications' : 'Listener not connected — toggle notification access off/on, then try again',
    );
    await _readLog(again: true);
  }

  /// The owner says a logged notification is a real payment: make its card.
  /// A row gets one card: a second tap, also after the first one ends, does nothing.
  /// 0.1.1 shows no text for a failure, so a failure is only logged.
  Future<void> markAsPayment(LoggedNotification n) async {
    if (_marked.contains(n.id) || !_marking.add(n.id)) return;
    try {
      final added = await _s.pending.forceCapture(
        sourcePackage: n.packageName,
        rawText: n.body,
        notificationPostTime: n.postTime,
      );
      if (!added) {
        _setMessage('No RM amount in this text. Add the payment by hand.');
        return;
      }
      _marked.add(n.id);
      if (!_disposed) notifyListeners();
      await _s.captureHost.updateLog(
        n.id,
        NotificationDisposition.waiting,
        'Added as a card. Check it on the Home screen.',
      );
      _generation++;
      await _readLog(again: true);
    } catch (e, s) {
      _log('Add as payment failed', e, s);
    } finally {
      _marking.remove(n.id);
    }
  }

  void dismissMessage() => _setMessage(null);

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}
