import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../capture/capture_host.dart';
import '../../capture/listener_control.dart';
import '../../data/undoable.dart';

/// Which rows of the log show. Saved: the text became a payment waiting in Check payments.
/// Not a payment: Koban skipped it. No text: the notification had no text.
enum LogFilter { all, saved, notPayment, noText }

bool _skipped(NotificationDisposition d) =>
    d != NotificationDisposition.waiting &&
    d != NotificationDisposition.pending &&
    d != NotificationDisposition.infoOnly;

/// The rows that [f] lets through.
List<LoggedNotification> filterLog(
  List<LoggedNotification> rows,
  LogFilter f,
) => switch (f) {
  LogFilter.all => rows,
  LogFilter.saved => [
    for (final n in rows)
      if (n.disposition == NotificationDisposition.waiting) n,
  ],
  LogFilter.notPayment => [
    for (final n in rows)
      if (_skipped(n.disposition) &&
          n.disposition != NotificationDisposition.skippedEmpty)
        n,
  ],
  LogFilter.noText => [
    for (final n in rows)
      if (n.disposition == NotificationDisposition.skippedEmpty) n,
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

  /// The rows that Clear log hides until its Undo time ends.
  final Set<String> _hidden = {};

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
  Map<String, String> _appLabels = const {};
  var _filter = LogFilter.all;
  String? _message;

  bool get isAccessGranted => _isAccessGranted;
  bool get isConnected => _isConnected;
  ListenerState get listenerState => _listenerState;

  /// The name of the app that sent [packageName]. The package name stands in until the label loads.
  String appLabel(String packageName) => _appLabels[packageName] ?? packageName;

  /// How many rows of the log are from today (by post time, as the list shows them),
  /// how many of those are saved (waiting in Check payments) and how many were skipped.
  (int seen, int saved, int skipped) todayCounts(DateTime now) {
    var seen = 0;
    var saved = 0;
    var skipped = 0;
    for (final n in _rows) {
      final at = DateTime.fromMillisecondsSinceEpoch(n.postTime);
      if (at.year != now.year || at.month != now.month || at.day != now.day) {
        continue;
      }
      seen++;
      if (n.disposition == NotificationDisposition.waiting) saved++;
      if (_skipped(n.disposition)) skipped++;
    }
    return (seen, saved, skipped);
  }

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
        _rows = [
          for (final n in rows)
            if (!_hidden.contains(n.id)) n,
        ];
        _listenerState = state;
        _isConnected = connected;
        _readFailing = false;
        await _loadLabels(rows);
        if (_disposed) return;
        notifyListeners();
      } while (_readAgain);
    } catch (e, s) {
      if (!_readFailing) _log('Log read failed', e, s);
      _readFailing = true;
    } finally {
      _reading = false;
    }
  }

  /// Asks the phone for the names of the apps that are not known yet. A failure keeps the package names.
  Future<void> _loadLabels(List<LoggedNotification> rows) async {
    final missing = {
      for (final n in rows)
        if (!_appLabels.containsKey(n.packageName)) n.packageName,
    };
    if (missing.isEmpty) return;
    try {
      final labels = await _s.device.appLabels(missing);
      _appLabels = {..._appLabels, for (final p in missing) p: labels[p] ?? p};
    } catch (e, s) {
      // Do not ask again at each poll.
      _appLabels = {..._appLabels, for (final p in missing) p: p};
      _log('App names failed', e, s);
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

  /// Hides the rows that show now. The native log is cleared when the Undo time ends,
  /// so Undo only shows the rows again. Nothing shows, so nothing to undo: it clears
  /// at once and returns null.
  /// ponytail: a process kill in the Undo time keeps the log, which is the safe side.
  Future<Undoable?> clearLog() async {
    if (_rows.isEmpty) {
      await _s.listener.clearLog();
      _generation++;
      await _readLog(again: true);
      return null;
    }
    final ids = {for (final n in _rows) n.id};
    _hidden.addAll(ids);
    _rows = const [];
    notifyListeners();
    return Undoable(
      undo: () async {
        _hidden.removeAll(ids);
        await _readLog(again: true);
      },
      commit: () async {
        // Only the rows that were hidden. A notification of the 6 s stays.
        await _s.listener.clearLog(ids: ids);
        _generation++;
        _hidden.removeAll(ids);
        if (!_disposed) await _readLog(again: true);
      },
    );
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
