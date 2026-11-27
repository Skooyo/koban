import 'dart:developer' as developer;

import 'package:http/http.dart' show Client;
import 'package:supabase/supabase.dart';

import '../data/database.dart';
import '../data/settings_store.dart';
import 'google_accounts.dart';
import 'group_repository.dart';
import 'group_session.dart';
import 'online_config.dart';
import 'online_http.dart';
import 'receipt_cloud_client.dart';
import 'secret_store.dart';

/// The online parts of the app: the build-time settings, the shared HTTP client,
/// the secrets and the Supabase client. Every network call first reads [allowed].
class OnlineServices {
  OnlineServices({
    required this.config,
    required this.http,
    required this.secrets,
    required this.settings,
    required this._db,
    this._now = DateTime.now,
    GoogleAccounts? google,
  }) : google = google ?? PhoneGoogleAccounts(config.googleWebClientId);

  final KobanDatabase _db;
  final DateTime Function() _now;

  final OnlineConfig config;

  /// The one HTTP client of the app. Tests give a `MockClient`.
  final Client http;
  final SecretStore secrets;
  final KobanSettings settings;

  /// The Supabase client, made at the first use (it starts a JSON isolate).
  /// Automatic token refresh is off, so no timer makes a call when Online features are off.
  SupabaseClient get supabase => _supabase ??= SupabaseClient(
    config.supabaseUrl,
    config.supabaseKey,
    httpClient: TimeoutClient(http),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    // One try for each read, as 0.1.1. Only `supabase.rest` and `supabase.rpc` use
    // these options: `supabase.from` ignores them (supabase 2.16.5), so the
    // group code calls `rest.from`.
    postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
  );
  SupabaseClient? _supabase;

  /// Stops the Supabase client and its JSON isolate, when the client was made.
  /// The app never calls it: the client lives with the process. Tests call it.
  Future<void> dispose() async => _supabase?.dispose();

  /// The group sign-in. It listens to the auth events of [supabase].
  late final GroupSession session = GroupSession(this);

  /// Google sign-in. Tests give a fake.
  final GoogleAccounts google;

  /// The groups: reads, actions and the shared totals sync. Made at the first use.
  late final GroupRepository groups = GroupRepository(
    online: this,
    session: session,
    google: google,
    db: _db,
    now: _now,
  );

  /// The receipt functions of Koban's server.
  late final ReceiptCloudClient receiptCloud = ReceiptCloudClient(this);

  /// Trades the invite code for a device token and stores the token (never the code).
  /// Gives an error message for the person, or null when it worked.
  Future<String?> useInviteCode(String code) async {
    final Registration r;
    try {
      r = await receiptCloud.register(code);
    } catch (e) {
      // Log only the type: the message of a body error can hold the token.
      developer.log(
        'Invite code check failed: ${e.runtimeType}',
        name: 'Online',
      );
      return "Koban's server had a problem. Try again later.";
    }
    switch (r) {
      case RegistrationFailed(:final message):
        return message;
      case RegistrationOk(:final deviceToken):
        try {
          await secrets.setDeviceToken(deviceToken);
        } catch (e) {
          developer.log(
            'Invite code save failed: ${e.runtimeType}',
            name: 'Online',
          );
          return 'Koban could not save the invite code on this phone. Try again.';
        }
        return null;
    }
  }

  /// True when the Online features switch is on.
  bool get allowed => settings.onlineFeatures.value;
}
