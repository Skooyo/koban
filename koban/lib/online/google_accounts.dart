import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart' hide GoogleIdentity;

import '../data/ids.dart';

/// A Google account that signed in. [rawNonce] is the nonce before the hash.
class GoogleIdentity {
  const GoogleIdentity(this.idToken, this.rawNonce, this.alias);

  final String idToken;
  final String rawNonce;
  final String alias;
}

/// Google sign-in did not give an account. [message] is the 0.1.1 text for the friend.
class GoogleSignInError implements Exception {
  const GoogleSignInError(this.message);

  final String message;
}

/// Gives a Google ID token. Tests give a fake.
abstract interface class GoogleAccounts {
  /// The account, or null when the person cancels.
  Future<GoogleIdentity?> signIn();
}

/// Google sign-in on the phone: on Android the "Sign in with Google" button flow
/// of Credential Manager, as 0.1.1.
class PhoneGoogleAccounts implements GoogleAccounts {
  PhoneGoogleAccounts(this._serverClientId);

  final String _serverClientId;

  /// The raw nonce. The plugin starts one time in each process, so all tries
  /// in one app run use this nonce (0.1.1 made one for each try).
  Future<String>? _nonce;

  Future<String> _start() async {
    final rawNonce = newId();
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId,
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
    return rawNonce;
  }

  @override
  Future<GoogleIdentity?> signIn() async {
    try {
      final String rawNonce;
      try {
        rawNonce = await (_nonce ??= _start());
      } catch (_) {
        _nonce = null; // The next try starts the plugin again.
        // For example a PlatformException: 0.1.1 showed this text for each failed request.
        throw const GoogleSignInError(_failed);
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const GoogleSignInError(
          'Google sign-in did not return an account.',
        );
      }
      return GoogleIdentity(
        idToken,
        rawNonce,
        aliasOf(idToken, account.displayName),
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw const GoogleSignInError(_failed);
    }
  }

  static const _failed =
      'Google sign-in failed. Add a Google account to this phone and try again.';
}

/// The name for the group pages: the `given_name` of the ID token, else [displayName],
/// else `Friend` (the 0.1.1 order). The token signature is not checked.
String aliasOf(String idToken, String? displayName) {
  String? givenName;
  try {
    final parts = idToken.split('.');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    givenName = (payload as Map<String, Object?>)['given_name'] as String?;
  } catch (_) {
    givenName = null;
  }
  return givenName ?? displayName ?? 'Friend';
}
