import 'dart:convert';
import 'dart:io' show IOException;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../device/device_control.dart';
import '../rules/receipt_cloud.dart' as rules;
import '../rules/receipt_cloud.dart'
    show CloudRead, CloudReadFailed, CloudReadOk;
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
  ReceiptCloudClient(
    this._online, {
    Future<Uint8List?> Function(String path)? shrink,
  }) : _shrink = shrink ?? DeviceControl().shrinkReceipt;

  final OnlineServices _online;

  /// Makes the photo small for the upload.
  final Future<Uint8List?> Function(String path) _shrink;

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

  static const notReachable = 'Claude was not reachable.';
  static const couldNotRead =
      "Claude could not read this receipt. This used 1 of today's reads.";

  /// Sends the photo at [path] to Claude. With Online features off, it
  /// sends nothing. The log has the error type only: no body, token, path or photo.
  Future<CloudRead> read(String path, String deviceToken) async {
    if (!_online.allowed) return const CloudReadFailed(onlineOff);
    final Uint8List? photo;
    try {
      photo = await _shrink(path);
    } catch (e) {
      debugPrint('Koban: photo shrink failed (${e.runtimeType})');
      return const CloudReadFailed(notReachable);
    }
    if (photo == null) return const CloudReadFailed(notReachable);
    final client = TimeoutClient(_online.http, timeout: _timeout);
    try {
      final r = await client.post(
        _online.config.function('read-receipt'),
        headers: {
          'Authorization': 'Bearer $deviceToken',
          'Content-Type': 'image/jpeg',
        },
        body: photo,
      );
      return switch (r.statusCode) {
        200 => _okOrUnreadable(r.body),
        401 => const CloudReadFailed(
          'Your invite code is no longer active.',
          tokenRevoked: true,
        ),
        429 => CloudReadFailed(switch (_limit(r.body)) {
          'all' => "Koban reached today's Claude limit.",
          'code' => 'Your invite code used all its Claude reads for today.',
          _ => 'You used your 10 Claude reads for today.',
        }),
        502 || 504 => const CloudReadFailed(couldNotRead, usedRead: true),
        _ => const CloudReadFailed(notReachable),
      };
    } catch (e) {
      debugPrint('Koban: Claude read failed (${e.runtimeType})');
      // 0.1.1 caught IOException: a TLS failure is also "not reachable".
      if (isNoConnection(e) || e is IOException) {
        return const CloudReadFailed(notReachable);
      }
      rethrow;
    }
  }

  static CloudRead _okOrUnreadable(String body) {
    final read = rules.ReceiptCloudClient.parse(body);
    if (read == null) {
      return const CloudReadFailed(couldNotRead, usedRead: true);
    }
    final left = (jsonDecode(body) as Map<String, Object?>)['readsLeftToday'];
    return CloudReadOk(read, left is num && left >= 0 ? left.toInt() : null);
  }

  static String? _limit(String body) {
    try {
      return (jsonDecode(body) as Map<String, Object?>)['limit'] as String?;
    } catch (_) {
      return null;
    }
  }

  static const _unreachable = RegistrationFailed(
    "Could not reach Koban's server. Check the internet connection.",
  );
}
