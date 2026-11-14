import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase/supabase.dart';

import 'google_accounts.dart';
import 'online_http.dart';
import 'online_services.dart';

/// The result of [GroupSession.restore].
enum RestoreResult {
  /// Online features are off, or no session is stored. No request was sent.
  none,

  /// The session is live.
  restored,

  /// The server refused the refresh token. The stored session is removed.
  refused,

  /// The phone did not reach the server. The stored session stays for the next try.
  noConnection,
}

/// The group sign-in. It keeps the session in the secrets store in the 0.1.1 format
/// `{"access_token", "refresh_token", "expires_at" (seconds), "user_id"}`.
/// Never log a value of the session.
class GroupSession {
  GroupSession(this._online) {
    _events = _auth.onAuthStateChange.listen(
      _onAuthEvent,
      // GoTrue puts a failed refresh on this stream. The call that started the refresh gets the error too.
      onError: (Object e, StackTrace s) {},
    );
  }

  final OnlineServices _online;
  late final StreamSubscription<AuthState> _events;

  /// The stored session, decoded. Null when signed out, and before the first [restore].
  Map<String, Object?>? _stored;

  /// The writes to the secrets store, one after the other.
  Future<void> _writes = Future.value();

  GoTrueClient get _auth => _online.supabase.auth;

  /// The user id of the live session, else the `user_id` of the stored session.
  /// Null when signed out. Read it after [restore].
  String? get userId {
    final stored = _stored;
    if (stored == null) return null;
    final id = stored['user_id'];
    return _auth.currentSession?.user.id ?? (id is String ? id : null);
  }

  /// True when a session is stored. Read it after [restore].
  bool get hasStoredSession => _stored != null;

  /// Reads the stored session. It sends no request, so [userId] has a value
  /// before a slow [restore] ends.
  Future<void> load() async {
    await _writes;
    _stored = _decode(await _online.secrets.groupSession());
  }

  /// Makes the stored session live. With Online features off, or with no stored session,
  /// it sends no request. A live session sends no request. Else it sends the stored
  /// refresh token one time. A 5xx of the server throws its [AuthRetryableFetchException].
  Future<RestoreResult> restore() async {
    await load();
    final stored = _stored;
    if (!_online.allowed || stored == null) return RestoreResult.none;
    final live = _auth.currentSession;
    if (live != null && !live.isExpired) return RestoreResult.restored;
    try {
      final r = await _auth.setSession(stored['refresh_token']! as String);
      await _save(r.session);
      return RestoreResult.restored;
    } catch (e) {
      // A 5xx: GoTrue and the stored JSON keep the session. The caller shows the
      // 0.1.1 server-problem text.
      if (e is AuthRetryableFetchException && e.statusCode != null) rethrow;
      if (isNoConnection(e)) return RestoreResult.noConnection;
      final status = e is AuthException
          ? int.tryParse(e.statusCode ?? '')
          : null;
      // GoTrue also removes the session for a 4xx with no JSON body
      // (AuthUnknownException) and for a reply with no session.
      if ((status != null && status >= 400 && status < 500) ||
          _auth.currentSession == null) {
        await _save(null);
        return RestoreResult.refused;
      }
      rethrow;
    }
  }

  /// Signs in with the Google ID token of [g] and stores the session. Returns the user id.
  Future<String> signInWithIdToken(GoogleIdentity g) async {
    if (!_online.allowed) throw AuthException('Online features are off.');
    final r = await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: g.idToken,
      nonce: g.rawNonce,
    );
    await _save(r.session);
    return r.session!.user.id;
  }

  /// Removes the session from the phone. With Online features on, GoTrue also ends
  /// this session (scope `local`) on the server. This method does not wait for that
  /// request, and a failure of it is ignored.
  Future<void> signOut() async {
    final live = _auth.currentSession != null;
    final write = _save(null);
    if (live && _online.allowed) {
      // GoTrue removes its session before it sends the request.
      _auth.signOut(scope: SignOutScope.local).catchError((
        Object e,
        StackTrace s,
      ) {
        // ONLINE LOGS rule R1: the type only, no stack trace.
        debugPrint('Koban: sign-out request failed (${e.runtimeType})');
      }).ignore();
    }
    await write;
  }

  /// Stops the listener.
  void dispose() => _events.cancel().ignore();

  void _onAuthEvent(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.signedIn ||
          AuthChangeEvent.tokenRefreshed ||
          AuthChangeEvent.signedOut:
        // The current session, not the session of the event: a late event writes no old session.
        _save(_auth.currentSession).ignore();
      default:
        break;
    }
  }

  /// Stores [session] in the 0.1.1 format. Null removes the stored session.
  /// A failed write is logged with its type only.
  Future<void> _save(Session? session) {
    final stored = session == null
        ? null
        : <String, Object?>{
            'access_token': session.accessToken,
            'refresh_token': session.refreshToken,
            'expires_at': session.expiresAt,
            'user_id': session.user.id,
          };
    _stored = stored;
    final text = stored == null ? null : jsonEncode(stored);
    return _writes = _writes
        .then((_) => _online.secrets.setGroupSession(text))
        .catchError((Object e, StackTrace s) {
          debugPrint('Koban: group session write failed (${e.runtimeType})');
        });
  }

  /// The stored session, or null when it is missing, not JSON or has no refresh token.
  static Map<String, Object?>? _decode(String? json) {
    if (json == null) return null;
    try {
      final m = jsonDecode(json);
      return m is Map<String, Object?> &&
              m['refresh_token'] is String &&
              (m['refresh_token']! as String).isNotEmpty
          ? m
          : null;
    } on FormatException {
      return null;
    }
  }
}
