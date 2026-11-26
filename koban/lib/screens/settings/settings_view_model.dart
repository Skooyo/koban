import 'dart:async';
import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../app/app_services.dart';
import '../../capture/listener_control.dart';
import '../../data/database.dart';
import '../../data/undoable.dart';
import '../../data/user_error.dart';
import '../../rules/amount_formatter.dart';
import '../../rules/payment_rules.dart';
import '../../rules/types.dart';
import '../../update/update_repository.dart';

/// The Xiaomi background steps of 0.1.1 (`OemBatteryHelper.xiaomiChecklist`).
const xiaomiChecklist = <String>[
  'Security app → Autostart → turn ON for Koban',
  'Settings → Apps → Koban → App permissions → Background autostart → Allow',
  'Settings → Apps → Koban → Battery saver → No restrictions',
  'Settings → Apps → Koban → turn OFF “Restrict background activity” if shown',
  'Recent apps → long-press Koban → tap the lock icon (do not “Clear all”)',
  'Keep the persistent “Tracking payment notifications” notification visible',
  'If notification access keeps turning off, disable MIUI optimizations in Developer options',
];

/// The color of a category that the friend adds.
const _newCategoryColor = '#5C6BC0';

/// The state of Settings: the listener status, the switches, the categories and the parser tool.
class SettingsViewModel extends ChangeNotifier with LoadErrors {
  /// [reconnectWait] is the time between the reconnect and its result. 0.1.1 waits 65 s.
  SettingsViewModel(
    this._s, {
    this.reconnectWait = const Duration(seconds: 65),
  }) {
    _subs.add(
      _s.categories.watchAll().listen((list) {
        _categories = list;
        notifyListeners();
      }, onError: onLoadError),
    );
    _subs.add(
      _s.budgets.watchLimits().listen((map) {
        _limits = map;
        notifyListeners();
      }, onError: onLoadError),
    );
    for (final l in _listenables) {
      l.addListener(notifyListeners);
    }
  }

  final AppServices _s;
  final Duration reconnectWait;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _reconnectTimer;
  var _disposed = false;
  var _reconnectPending = false;

  Iterable<Listenable> get _listenables => [
    _s.settings.darkMode,
    _s.settings.onlineFeatures,
    _s.settings.hasDeviceToken,
    _s.settings.paymentApps,
    _s.updates.state,
  ];

  bool _isAccessGranted = false;
  bool _isBatteryOptimizationIgnored = true;
  bool _isXiaomi = false;
  int _capturedCount = 0;
  String _versionName = '';
  List<Category> _categories = const [];
  Map<String, Decimal> _limits = const {};
  String? _reconnectMessage;
  String? _parserResult;
  var _inviteBusy = false;
  String? _inviteMessage;

  bool get isAccessGranted => _isAccessGranted;
  bool get isBatteryOptimizationIgnored => _isBatteryOptimizationIgnored;
  bool get isXiaomi => _isXiaomi;
  bool get onlineFeatures => _s.settings.onlineFeatures.value;

  /// True after a manual check that found nothing new.
  bool get upToDate => _s.updates.state.value is UpdateUpToDate;

  /// The manual check. The update dialog shows the result.
  Future<void> checkForUpdates() => _s.updates.check(manual: true);

  bool get hasDeviceToken => _s.settings.hasDeviceToken.value;
  bool get darkMode => _s.settings.darkMode.value;
  int get paymentAppCount => _s.settings.paymentApps.value.length;
  int get capturedCount => _capturedCount;
  String get versionName => _versionName;
  List<Category> get categories => _categories;

  /// The limit of this month for each category that has one.
  Map<String, Decimal> get limits => _limits;
  String? get reconnectMessage => _reconnectMessage;
  String? get parserResult => _parserResult;
  bool get inviteBusy => _inviteBusy;
  String? get inviteMessage => _inviteMessage;

  /// Reads the phone state again and starts the listener. The screen calls it at the start and at each resume.
  Future<void> refresh() async {
    try {
      final l = _s.listener;
      final granted = await l.isAccessGranted();
      await l.ensureActive();
      final ignored = await l.isBatteryOptimizationIgnored();
      final xiaomi = await l.isXiaomiFamily();
      final log = await l.recentNotifications();
      final version = await _s.device.versionName();
      if (_disposed) return;
      _isAccessGranted = granted;
      _isBatteryOptimizationIgnored = ignored;
      _isXiaomi = xiaomi;
      _capturedCount = log.length;
      _versionName = version;
      notifyListeners();
    } catch (e, s) {
      _log('Refresh failed', e, s);
    }
  }

  static void _log(String message, Object e, StackTrace s) =>
      developer.log(message, name: 'Settings', error: e, stackTrace: s);

  void _setReconnect(String? message) {
    if (_disposed) return;
    _reconnectMessage = message;
    notifyListeners();
  }

  /// Asks the native listener to reconnect. After a good attempt, the result shows [reconnectWait] later.
  /// A tap while an attempt waits does nothing.
  Future<void> reconnect() async {
    if (_reconnectPending) return;
    _reconnectPending = true;
    _setReconnect('Reconnecting…');
    try {
      final result = await _s.listener.reconnect();
      switch (result) {
        case ReconnectResult.accessNotGranted:
          _setReconnect(
            'Notification access was removed — re-enable it in system settings. '
            'On Xiaomi, enable Autostart and avoid clearing the app from recents.',
          );
        case ReconnectResult.throttled:
          _setReconnect(
            'Reconnect already attempted recently — wait a moment and try again.',
          );
        case ReconnectResult.failed:
          _setReconnect(
            'Reconnect failed — open notification access settings.',
          );
        case ReconnectResult.attempted:
          if (_disposed) return;
          _reconnectTimer = Timer(reconnectWait, _showReconnectResult);
          return;
      }
    } catch (e, s) {
      _log('Reconnect failed', e, s);
      _setReconnect('Reconnect failed — open notification access settings.');
    }
    _reconnectPending = false;
  }

  Future<void> _showReconnectResult() async {
    try {
      final connected = await _s.listener.isConnected();
      _setReconnect(
        connected ? 'Tracking is connected.' : 'Still disconnected after 60s — tap the alert notification or open notification access settings.',
      );
    } catch (e, s) {
      _log('Reconnect check failed', e, s);
    } finally {
      _reconnectPending = false;
    }
  }

  Future<void> openNotificationSettings() => _s.listener.openAccessSettings();

  Future<void> openBatterySettings() =>
      _s.listener.openBatteryOptimizationSettings();

  Future<void> openBackgroundSettings() async {
    await _s.listener.openBackgroundSettings();
  }

  Future<void> setDarkMode(bool on) => _s.settings.setDarkMode(on);

  Future<void> setOnlineFeatures(bool on) => _s.settings.setOnlineFeatures(on);

  /// Trades the invite code for a device token. It stores only the token, never the code.
  /// A call while a check runs does nothing.
  Future<void> enterInviteCode(String code) async {
    if (_inviteBusy) return;
    _inviteBusy = true;
    _inviteMessage = null;
    notifyListeners();
    final message = await _s.online.useInviteCode(code);
    _inviteBusy = false;
    _inviteMessage = message;
    if (!_disposed) notifyListeners();
  }

  Future<void> removeDeviceToken() => _s.settings.removeDeviceToken();

  /// Reads [text] with the payment rules, as the capture engine does, and shows the result.
  void runParserTest(String text) {
    _parserResult = switch (PaymentRules.match('', text.trim())) {
      Matched(:final expense) =>
        'Amount: ${AmountFormatter.currencySymbol(expense.currency)} ${AmountFormatter.formatDisplay(expense.amount)}\n'
            'Shop: ${expense.merchant ?? '—'}\n'
            'Kind: ${expense.transactionType == TransactionType.receive ? 'Received' : 'Spent'}',
      NoMatch() => 'No rule matched this text',
    };
    notifyListeners();
  }

  Future<void> addCategory(String name) =>
      _s.categories.addCategory(name, _newCategoryColor);

  /// The category that has this name, ignoring case, or null.
  Category? categoryNamed(String name) {
    final wanted = name.trim().toLowerCase();
    for (final c in _categories) {
      if (c.name.toLowerCase() == wanted) return c;
    }
    return null;
  }

  /// Deletes an own category. It returns how many payments become Uncategorized,
  /// and the Undo, or null when nothing went.
  Future<({Undoable undo, int payments})?> deleteCategory(String id) async {
    final payments = await _s.categories.paymentCount(id);
    final undo = await _s.categories.deleteCategory(id);
    return undo == null ? null : (undo: undo, payments: payments);
  }

  /// Saves the limit of this month. Null clears it.
  Future<void> saveLimit(String categoryId, Decimal? amount) => amount == null
      ? _s.budgets.clearLimit(categoryId)
      : _s.budgets.setLimit(categoryId, amount);

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    for (final l in _listenables) {
      l.removeListener(notifyListeners);
    }
    super.dispose();
  }
}
