import 'dart:convert';

import 'package:http/http.dart' as http;

import 'online_http.dart';
import 'online_services.dart';

/// The answer of Koban's server to an invite code.
sealed class Registration {
  const Registration();
}

/// The server accepted the code and gave a device token.
final class RegistrationOk extends Registration {
  const RegistrationOk(this.deviceToken);
  final String deviceToken;
}

/// The server did not accept the code. [message] is the text for the friend.
final class RegistrationFailed extends Registration {
  const RegistrationFailed(this.message);
  final String message;
}

/// Talks to Koban's Supabase edge functions. Port of the 0.1.1 `ReceiptCloudClient`.
class ReceiptCloudClient {
  ReceiptCloudClient(this._online);

  final OnlineServices _online;

  /// The text when the Online features switch is off.
  static const onlineOff =
      'Turn on online features in Settings to read with Claude.';

  /// Claude 60 s, then the edge function 70 s, then the app 90 s, as 0.1.1.
  static const _timeout = Duration(seconds: 90);

  /// Trades an invite code for a device token. With Online features off, it sends no request.
  /// The request has no `Authorization` header, as in 0.1.1.
  Future<Registration> register(String inviteCode) async {
    if (!_online.allowed) return const RegistrationFailed(onlineOff);
    final client = TimeoutClient(_online.http, timeout: _timeout);
    try {
      final r = await client.post(
        _online.config.function('register'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'inviteCode': inviteCode.trim().toUpperCase()}),
      );
      return switch (r.statusCode) {
        200 => RegistrationOk(
          (jsonDecode(r.body) as Map<String, Object?>)['deviceToken']!
              as String,
        ),
        400 => const RegistrationFailed(
          'The invite code looks like XXXX-XXXX.',
        ),
        429 => const RegistrationFailed(
          'Too many tries. Try again in an hour.',
        ),
        403 => const RegistrationFailed('Invite code not accepted.'),
        _ => const RegistrationFailed(
          "Koban's server had a problem. Try again later.",
        ),
      };
    } on http.ClientException catch (_) {
      return _unreachable;
    } catch (e) {
      if (isNoConnection(e)) return _unreachable;
      rethrow;
    }
  }

  static const _unreachable = RegistrationFailed(
    "Could not reach Koban's server. Check the internet connection.",
  );
}
