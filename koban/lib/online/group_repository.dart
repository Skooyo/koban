import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';
import 'package:supabase/supabase.dart';

import '../data/category_repository.dart';
import '../data/database.dart';
import '../rules/amount_formatter.dart';
import '../rules/periods.dart';
import 'google_accounts.dart';
import 'group_session.dart';
import 'online_http.dart';
import 'online_services.dart';

/// One group in the groups list.
class GroupSummary {
  const GroupSummary(
    this.id,
    this.name,
    this.code,
    this.ownerId,
    this.members,
    this.requests,
  );

  final String id;
  final String name;
  final String code;
  final String? ownerId;
  final int members;
  final int requests;
}

/// A request to join a group. [alias] is the name of the person who asks.
/// [sentAt] is when the person sent it.
class JoinRequest {
  const JoinRequest(this.groupId, this.userId, this.alias, [this.sentAt]);

  final String groupId;
  final String userId;
  final String alias;
  final DateTime? sentAt;
}

/// A group member with the shared totals of the shown period.
class Member {
  const Member({
    required this.userId,
    required this.alias,
    required this.joinedAt,
    required this.updatedAt,
    required this.categories,
  });

  final String userId;
  final String alias;
  final DateTime joinedAt;
  final DateTime? updatedAt;

  /// Category name to amount for the shown period, largest first.
  // Budget limits (the budget_limits table) show here once personal budgets exist (map #33).
  final List<(String, Decimal)> categories;

  Decimal get total => categories.fold(Decimal.zero, (sum, c) => sum + c.$2);
}

/// One group with its members and its open join requests.
class GroupDetail {
  const GroupDetail(this.group, this.members, this.requests);

  final GroupSummary group;
  final List<Member> members;
  final List<JoinRequest> requests;
}

/// The state of the Groups tab.
class GroupsState {
  const GroupsState({
    this.online = true,
    this.userId,
    this.alias = '',
    this.groups = const [],
    this.requests = const [],
    this.waiting = const [],
    this.removedFrom = const [],
    this.loading = false,
    this.namePending = false,
    this.message,
  });

  final bool online;
  final String? userId;
  final String alias;
  final List<GroupSummary> groups;
  final List<JoinRequest> requests;

  /// The requests that this person sent and the group owners did not answer yet.
  final List<JoinRequest> waiting;

  /// The notices of groups that removed this person: (notice id, group name).
  final List<(int, String)> removedFrom;
  final bool loading;

  /// True after the first sign-in, until the person picks the name for groups.
  final bool namePending;
  final String? message;

  static const _keep = Object();

  /// A copy with the given values. Give `null` to [userId] or [message] to remove the value.
  GroupsState copyWith({
    bool? online,
    Object? userId = _keep,
    String? alias,
    List<GroupSummary>? groups,
    List<JoinRequest>? requests,
    List<JoinRequest>? waiting,
    List<(int, String)>? removedFrom,
    bool? loading,
    bool? namePending,
    Object? message = _keep,
  }) => GroupsState(
    online: online ?? this.online,
    userId: identical(userId, _keep) ? this.userId : userId as String?,
    alias: alias ?? this.alias,
    groups: groups ?? this.groups,
    requests: requests ?? this.requests,
    waiting: waiting ?? this.waiting,
    removedFrom: removedFrom ?? this.removedFrom,
    loading: loading ?? this.loading,
    namePending: namePending ?? this.namePending,
    message: identical(message, _keep) ? this.message : message as String?,
  );
}

/// Groups: sign-in, actions, reads and the shared totals sync. A port of the 0.1.1
/// `GroupRepository.kt`.
/// With Online features off, no method sends a request.
class GroupRepository {
  GroupRepository({
    required this._online,
    required this._session,
    required this._google,
    required this._db,
    required this._now,
    this._syncDelay = const Duration(seconds: 5),
  });

  final OnlineServices _online;
  final GroupSession _session;
  final GoogleAccounts _google;
  final KobanDatabase _db;
  final DateTime Function() _now;
  final Duration _syncDelay;

  static const _onlineOff = 'Turn on online features first.';
  static const _unreachableText =
      "Could not reach Koban's server. Check the internet connection.";
  static const _signInAgain = 'Sign in again.';
  static const _serverProblem =
      "Koban's server had a problem. Try again later.";

  final _state = ValueNotifier(const GroupsState());
  final _inGroups = ValueNotifier(false);

  ValueListenable<GroupsState> get state => _state;

  /// True when this person is in a group (0.1.1 `PaymentViewModel.inGroups`).
  ValueListenable<bool> get inGroups => _inGroups;

  var _started = false;
  Timer? _syncTimer;
  StreamSubscription<void>? _expenseUpdates;

  bool get _allowed => _online.allowed;

  void _set(GroupsState s) {
    _state.value = s;
    _inGroups.value = s.groups.isNotEmpty;
  }

  /// Starts the work after Online features turn on, and the sync after payment changes.
  /// Call it one time, from the app's first screen.
  void start() {
    if (_started) return;
    _started = true;
    _online.settings.onlineFeatures.addListener(_onOnlineChanged);
    _onOnlineChanged();
    // ponytail: syncs while the app process lives (app open, or the listener service). Payments saved while
    // offline go up at the next change or app start; WorkManager would retry in the background.
    _expenseUpdates = _db
        .tableUpdates(TableUpdateQuery.onTable(_db.expenses))
        .listen((_) => _expensesChanged());
  }

  /// Stops the timer and the listeners.
  void dispose() {
    _syncTimer?.cancel();
    _online.settings.onlineFeatures.removeListener(_onOnlineChanged);
    _expenseUpdates?.cancel().ignore();
  }

  void _onOnlineChanged() {
    final on = _allowed;
    _set(_state.value.copyWith(online: on));
    if (!on) {
      _syncTimer?.cancel();
      return;
    }
    // refresh makes the stored session live first.
    refresh().then((_) => syncTotals()).catchError((Object e, StackTrace s) {
      debugPrint('Koban: group start failed (${e.runtimeType})');
    }).ignore();
  }

  /// Starts the sync after [_syncDelay] with no other payment change.
  void _expensesChanged() {
    if (!_allowed || _session.userId == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(_syncDelay, () => syncTotals().ignore());
  }

  // ---- Sign-in ----

  /// Google sign-in, then links the account to this phone's invite code.
  /// Returns an error message or null.
  Future<String?> signIn() async {
    if (!_allowed) return _onlineOff;
    final GoogleIdentity? google;
    try {
      google = await _google.signIn();
    } on GoogleSignInError catch (e) {
      return e.message;
    }
    if (google == null) return null;
    try {
      await _session.signInWithIdToken(google);
      final firstSignIn = await _isNewAccount();
      final linked = await _online.supabase.rpc(
        'link_account',
        params: {
          'p_device_token': _online.secrets.deviceToken.value,
          'p_alias': google.alias,
        },
      );
      if (linked != 'ok') {
        await _session.signOut();
        return 'Groups need online access. Enter your invite code in Settings first.';
      }
      await refresh();
      if (firstSignIn) _set(_state.value.copyWith(namePending: true));
      return null;
    } catch (e) {
      await _session.signOut();
      return _unreachable(e) ? _unreachableText : 'Sign-in failed. Try again.';
    }
  }

  /// True when the signed-in account has no profile yet, so this is its first sign-in.
  Future<bool> _isNewAccount() async {
    try {
      final rows = await _online.supabase.rest
          .from('profiles')
          .select('alias')
          .eq('user_id', _session.userId!);
      return rows.isEmpty;
    } catch (e) {
      // ONLINE LOGS rule R1: the type only.
      debugPrint('Koban: profile check failed (${e.runtimeType})');
      return false;
    }
  }

  /// The person picked a name, or kept the Google name.
  void nameDone() => _set(_state.value.copyWith(namePending: false));

  Future<void> signOut() async {
    await _session.signOut();
    _set(GroupsState(online: _state.value.online));
  }

  Future<String?> deleteAccount() => _act(() async {
    await (await _client()).functions.invoke('delete-account', body: {});
    await _session.signOut();
    _set(GroupsState(online: _state.value.online));
    return null;
  });

  // ---- Reads ----

  Future<void> refresh() async {
    if (!_allowed) {
      _set(_state.value.copyWith(userId: null, groups: const []));
      return;
    }
    try {
      // A restore with no connection can take about 12 s. As 0.1.1, the groups
      // page shows the stored user with the loading state while it waits.
      if (_online.supabase.auth.currentSession == null) {
        await _session.load();
        final stored = _session.userId;
        if (stored != null) {
          _set(
            _state.value.copyWith(userId: stored, loading: true, message: null),
          );
        }
      }
      await _restore();
      final uid = _session.userId;
      if (uid == null) {
        _set(_state.value.copyWith(userId: null, groups: const []));
        return;
      }
      // A new load clears the old message, so the same failure shows again.
      _set(_state.value.copyWith(userId: uid, loading: true, message: null));
      final sb = await _client();
      final profiles = await sb.rest
          .from('profiles')
          .select('alias')
          .eq('user_id', uid);
      final alias = profiles.isEmpty
          ? ''
          : (profiles.first['alias'] as String?) ?? '';
      final reqs = [
        for (final r
            in await sb.rest
                .from('join_requests')
                .select('group_id,user_id,created_at,profiles(alias)'))
          JoinRequest(
            r['group_id']! as String,
            r['user_id']! as String,
            _alias(r['profiles']),
            switch (r['created_at']) {
              final String t => DateTime.tryParse(t),
              _ => null,
            },
          ),
      ];
      final groups = [
        for (final g
            in await sb.rest
                .from('groups')
                .select('id,name,code,owner_id,group_members(user_id)')
                .order('created_at', ascending: true))
          GroupSummary(
            g['id']! as String,
            g['name']! as String,
            g['code']! as String,
            switch (g['owner_id']) {
              final String id when id.trim().isNotEmpty => id,
              _ => null,
            },
            (g['group_members'] as List?)?.length ?? 0,
            reqs.where((r) => r.userId != uid && r.groupId == g['id']).length,
          ),
      ];
      final removed = [
        for (final r
            in await sb.rest.from('removed_notices').select('id,group_name'))
          ((r['id']! as num).toInt(), r['group_name']! as String),
      ];
      _set(
        _state.value.copyWith(
          alias: alias,
          groups: groups,
          requests: [
            for (final r in reqs)
              if (r.userId != uid) r,
          ],
          waiting: [
            for (final r in reqs)
              if (r.userId == uid) r,
          ],
          removedFrom: removed,
          loading: false,
          message: null,
        ),
      );
    } catch (e) {
      final text = _errorText(e);
      final signedOut = text == _signInAgain;
      _set(
        _state.value.copyWith(
          loading: false,
          userId: signedOut ? null : _session.userId,
          // A signed-out person has no groups, so inGroups must be false.
          groups: signedOut ? const [] : null,
          message: text,
        ),
      );
    }
  }

  /// One group's members with their totals for the period that holds today.
  /// It throws when the reads fail.
  Future<GroupDetail?> loadGroup(
    String groupId,
    Period period,
    String currency,
  ) async {
    if (!_allowed) return null;
    final summary = _state.value.groups
        .where((g) => g.id == groupId)
        .firstOrNull;
    if (summary == null) return null;
    final start = GroupPeriodMath.start(
      GroupPeriodMath.malaysiaDay(_now()),
      period,
    );
    final sb = await _client();
    final rows = await sb.rest
        .from('group_members')
        .select('user_id,joined_at,profiles(alias,totals_updated_at)')
        .eq('group_id', groupId);
    final totals = await sb.rest
        .from('shared_totals')
        .select('user_id,category,amount')
        .inFilter('user_id', [for (final r in rows) r['user_id']! as String])
        .eq('currency', currency)
        .eq('period', period.key)
        .eq('period_start', _date(start));
    final members = [
      for (final r in rows)
        Member(
          userId: r['user_id']! as String,
          alias: _alias(r['profiles']),
          joinedAt: DateTime.parse(r['joined_at']! as String),
          updatedAt: switch (r['profiles']) {
            {'totals_updated_at': final String t} when t.trim().isNotEmpty =>
              DateTime.parse(t),
            _ => null,
          },
          categories: [
            for (final t in totals)
              if (t['user_id'] == r['user_id'])
                (t['category']! as String, Decimal.parse('${t['amount']}')),
          ]..sort((a, b) => b.$2.compareTo(a.$2)),
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return GroupDetail(
      summary,
      members,
      _state.value.requests.where((r) => r.groupId == groupId).toList(),
    );
  }

  // ---- Actions: each returns an error message, or null when it worked ----

  /// Makes a group. [onMade] gets the id of the new group.
  Future<String?> makeGroup(String name, {void Function(String id)? onMade}) =>
      _act(() async {
        final r = await (await _client()).rpc(
          'make_group',
          params: {'p_name': name},
        );
        return switch ((r as Map)['status']) {
          'ok' => () {
            onMade?.call('${r['id']}');
            return null;
          }(),
          'too_many_groups' => 'You are in 5 groups, the most allowed.',
          'bad_name' => 'Give the group a name of 1 to 40 characters.',
          _ => 'Groups need online access. Enter your invite code in Settings.',
        };
      });

  Future<String?> askToJoin(String code) => _act(() async {
    return switch (await _rpc('ask_to_join', {'p_code': code})) {
      'ok' => null,
      'unknown' =>
        'No group has this code. Check it with the person who sent it.',
      'already' => 'You are already in this group.',
      'full' => 'This group has 10 members, the most allowed.',
      'too_many_groups' => 'You are in 5 groups, the most allowed.',
      'too_many_requests' =>
        'You have 5 open requests. Wait for an answer first.',
      _ => 'Groups need online access. Enter your invite code in Settings.',
    };
  });

  Future<String?> answer(JoinRequest req, bool approve) => _act(() async {
    final r = await _rpc('answer_request', {
      'p_group': req.groupId,
      'p_user': req.userId,
      'p_approve': approve,
    });
    return switch (r) {
      'ok' || 'declined' => null,
      'expired' =>
        'This request is older than 7 days. Ask ${req.alias} to send it again.',
      'full' => 'The group has 10 members, the most allowed.',
      'too_many_groups' => '${req.alias} is in 5 groups, the most allowed.',
      _ => 'Only the group owner can answer requests.',
    };
  });

  Future<String?> leave(String groupId) =>
      _simple('leave_group', {'p_group': groupId});

  Future<String?> remove(String groupId, String userId) =>
      _simple('remove_member', {'p_group': groupId, 'p_user': userId});

  Future<String?> handOver(String groupId, String userId) =>
      _simple('hand_over', {'p_group': groupId, 'p_user': userId});

  Future<String?> rename(String groupId, String name) =>
      _simple('rename_group', {'p_group': groupId, 'p_name': name});

  Future<String?> newCode(String groupId) => _act(() async {
    final r = await _rpc('new_group_code', {'p_group': groupId});
    return r.startsWith('GRP-')
        ? null
        : 'Only the group owner can make a new code.';
  });

  Future<String?> setAlias(String alias) => _act(() async {
    final uid = _session.userId;
    if (uid == null) return 'Sign in first.';
    final trimmed = alias.trim();
    await (await _client()).rest
        .from('profiles')
        .update({
          'alias': trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed,
        })
        .eq('user_id', uid);
    return null;
  });

  Future<void> dismissRemoved(int id) async {
    if (_allowed) {
      try {
        await (await _client()).rest
            .from('removed_notices')
            .delete()
            .eq('id', id);
      } catch (e) {
        // ONLINE LOGS rule R1: the type only.
        debugPrint('Koban: removed notice delete failed (${e.runtimeType})');
      }
    }
    _set(
      _state.value.copyWith(
        removedFrom: [
          for (final r in _state.value.removedFrom)
            if (r.$1 != id) r,
        ],
      ),
    );
  }

  Future<String?> _simple(String fn, Map<String, Object?> args) =>
      _act(() async {
        final r = await _rpc(fn, args);
        return switch (r) {
          'ok' => null,
          'bad_name' => 'Give the group a name of 1 to 40 characters.',
          'use_leave' => 'Use Leave group to leave.',
          'not_owner' => 'Only the group owner can do this.',
          _ => 'This person is not in the group.',
        };
      });

  /// Calls an RPC that gives one JSON string, and gives that string.
  Future<String> _rpc(String fn, Map<String, Object?> args) async =>
      '${await (await _client()).rpc(fn, params: args)}';

  /// Runs a server action, then refreshes. Network and session errors become one message.
  Future<String?> _act(Future<String?> Function() block) async {
    if (!_allowed) return _onlineOff;
    try {
      final msg = await block();
      await refresh();
      await syncTotals();
      return msg;
    } catch (e) {
      final text = _errorText(e);
      if (text == _signInAgain) _set(_state.value.copyWith(userId: null));
      return text;
    }
  }

  /// The 0.1.1 text for [e]. As 0.1.1, a signed-out answer keeps the stored
  /// session: the state has no user id, and the next refresh tries again.
  String _errorText(Object e) {
    if (_unreachable(e)) return _unreachableText;
    if (_isSignedOut(e)) return _signInAgain;
    // ONLINE LOGS rule R1: the type only.
    debugPrint('Koban: group call failed (${e.runtimeType})');
    return _serverProblem;
  }

  /// True when the phone did not reach the server. A 5xx of GoTrue is a server problem, as 0.1.1.
  static bool _unreachable(Object e) =>
      isNoConnection(e) &&
      !(e is AuthRetryableFetchException && e.statusCode != null);

  bool _isSignedOut(Object e) => switch (e) {
    AuthRetryableFetchException() => false,
    // GoTrue removes its session when a refresh fails with no status (AuthUnknownException).
    AuthException(:final statusCode) =>
      _is4xx(statusCode) || _online.supabase.auth.currentSession == null,
    // The JWT errors of PostgREST, or a 401 with no JSON code.
    PostgrestException(:final code) => const {
      'PGRST301',
      'PGRST302',
      'PGRST303',
      '401',
    }.contains(code),
    FunctionException(:final status) => status == 401,
    _ => false,
  };

  static bool _is4xx(String? status) {
    final s = int.tryParse(status ?? '');
    return s != null && s >= 400 && s < 500;
  }

  /// Makes the stored session live when GoTrue has no session.
  /// Throws [AuthSessionMissingException] when the server refused it, and
  /// [AuthRetryableFetchException] when the phone did not reach the server or the server had a 5xx.
  Future<void> _restore() async {
    if (_online.supabase.auth.currentSession != null) return;
    switch (await _session.restore()) {
      case RestoreResult.refused:
        throw AuthSessionMissingException();
      case RestoreResult.noConnection:
        throw AuthRetryableFetchException();
      case RestoreResult.restored || RestoreResult.none:
        return;
    }
  }

  /// The Supabase client with a live session, as the 0.1.1 `authed` call.
  /// Throws [AuthSessionMissingException] when signed out.
  Future<SupabaseClient> _client() async {
    await _restore();
    final sb = _online.supabase;
    if (_session.userId == null || sb.auth.currentSession == null) {
      throw AuthSessionMissingException();
    }
    return sb;
  }

  // ---- Shared totals ----

  /// Sends this person's shared totals: every week and month from the earliest group join until now, for each account.
  /// Rows are replaced as a whole, so an edit to an earlier period or a moved category shows correctly.
  Future<void> syncTotals() async {
    if (!_allowed) return;
    final uid = _session.userId;
    if (uid == null) return;
    try {
      final sb = await _client();
      final joins = await sb.rest
          .from('group_members')
          .select('joined_at')
          .eq('user_id', uid);
      if (joins.isEmpty) return;
      final since = GroupPeriodMath.malaysiaDay(
        joins
            .map((j) => DateTime.parse(j['joined_at']! as String))
            .reduce((a, b) => a.isBefore(b) ? a : b),
      );
      final today = GroupPeriodMath.malaysiaDay(_now());
      final rows = <Map<String, Object?>>[];
      for (final currency in const ['MYR', 'IDR']) {
        for (final period in Period.values) {
          var start = GroupPeriodMath.start(since, period);
          while (!start.isAfter(today)) {
            final next = period == Period.week
                ? DateTime.utc(start.year, start.month, start.day + 7)
                : DateTime.utc(start.year, start.month + 1, 1);
            final totals = await _db
                .groupTotals(
                  CategoryRepository.uncategorizedName,
                  currency,
                  GroupPeriodMath.malaysiaDayStartMs(start),
                  GroupPeriodMath.malaysiaDayStartMs(next),
                )
                .get();
            for (final t in totals) {
              rows.add({
                'user_id': uid,
                'currency': currency,
                'period': period.key,
                'period_start': _date(start),
                'category': t.category.length > 40
                    ? t.category.substring(0, 40)
                    : t.category,
                'amount': AmountFormatter.formatDisplay(t.total!),
              });
            }
            start = next;
          }
        }
      }
      await sb.rest.from('shared_totals').delete().eq('user_id', uid);
      if (rows.isNotEmpty) await sb.rest.from('shared_totals').insert(rows);
      await sb.rest
          .from('profiles')
          .update({'totals_updated_at': _now().toUtc().toIso8601String()})
          .eq('user_id', uid);
    } catch (e) {
      // Offline or signed out: the next change or app start tries again.
      // ONLINE LOGS rule R1: the type only.
      debugPrint('Koban: shared totals sync failed (${e.runtimeType})');
    }
  }

  /// The alias in a `profiles(alias)` value, else `?`.
  static String _alias(Object? profiles) => switch (profiles) {
    {'alias': final String a} => a,
    _ => '?',
  };

  /// [day] as yyyy-MM-dd.
  static String _date(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}
