import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart' show AuthRetryableFetchException;

import '../../app/app_services.dart';
import '../../online/group_repository.dart';
import '../../online/online_http.dart';
import '../../rules/periods.dart';

/// The Groups tab and the page of one group. [groupId] is set only on the group page.
/// A port of `GroupsViewModel.kt`.
class GroupsViewModel extends ChangeNotifier {
  GroupsViewModel(this._s, {String? groupId}) : _groupId = groupId {
    _seenStateMessage = _repo.state.value.message;
    _repo.state.addListener(_onState);
    // The Groups tab refreshes at the app start (GroupRepository.start).
    if (groupId != null) unawaited(refresh());
  }

  final AppServices _s;
  final String? _groupId;

  GroupRepository get _repo => _s.online.groups;

  /// The last message of the repository state. A new message shows one time.
  String? _seenStateMessage;
  var _disposed = false;

  GroupsState get state => _repo.state.value;

  bool _busy = false;
  bool get busy => _busy;

  String? _message;

  /// The message for the snackbar. Call [messageShown] after it shows.
  String? get message => _message;

  Period _period = Period.month;
  Period get period => _period;

  GroupDetail? _detail;
  GroupDetail? get detail => _detail;

  /// False after a load that found the group gone (left, removed or deleted).
  bool _groupExists = true;
  bool get groupExists => _groupExists;

  /// When [detail] loaded.
  DateTime? _loadedAt;
  DateTime? get loadedAt => _loadedAt;

  void _onState() {
    final m = _repo.state.value.message;
    if (m != null && m != _seenStateMessage) _message = m;
    _seenStateMessage = m;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Sends the shared totals, then reads the groups again.
  Future<void> refresh() => run((r) async {
    await r.syncTotals();
    await r.refresh();
    return null;
  }, silent: true);

  void setPeriod(Period p) {
    _period = p;
    _notify();
    unawaited(_reloadNow());
  }

  /// Runs one group action. [onOk] runs when it worked; an error goes to [message].
  /// Every action ends with a new read of the open group. While an action runs,
  /// a second call returns at once. A [silent] action does not set [busy].
  Future<void> run(
    Future<String?> Function(GroupRepository r) action, {
    bool silent = false,
    VoidCallback? onOk,
  }) async {
    if (_busy) return;
    if (!silent) {
      _busy = true;
      _notify();
    }
    String? error;
    try {
      error = await action(_repo);
      await _reloadNow();
    } catch (e) {
      // ONLINE LOGS rule R1: the type only.
      debugPrint('Koban: group action failed (${e.runtimeType})');
      return;
    } finally {
      if (!silent) _busy = false;
      _notify();
    }
    if (_disposed) return;
    if (error == null) {
      onOk?.call();
    } else {
      _message = error;
      _notify();
    }
  }

  Future<void> setOnline(bool on) => _s.settings.setOnlineFeatures(on);

  void messageShown() => _message = null;

  Future<void> _reloadNow() async {
    final id = _groupId;
    if (id == null) return;
    final st = _repo.state.value;
    if (st.userId != null && !st.groups.any((g) => g.id == id)) {
      _groupExists = false;
      _notify();
      return;
    }
    try {
      // ponytail: RM only until the Rp account ships; then pass the Settings active account.
      _detail = await _repo.loadGroup(id, _period, 'MYR');
      _loadedAt = _s.now();
    } catch (e) {
      final unreachable =
          isNoConnection(e) &&
          !(e is AuthRetryableFetchException && e.statusCode != null);
      if (!unreachable) {
        // ONLINE LOGS rule R1: the type only.
        debugPrint('Koban: group load failed (${e.runtimeType})');
      }
      _message = unreachable
          ? "Could not reach Koban's server. Check the internet connection."
          : 'Could not load the group. Try again.';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _repo.state.removeListener(_onState);
    super.dispose();
  }
}
