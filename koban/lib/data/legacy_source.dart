import 'package:flutter/services.dart';

/// Gives the 0.1.1 data to the import. The real source reads the old app files.
abstract interface class LegacySource {
  /// The full path of the old Room database file.
  Future<String> databasePath();

  /// The old settings. Values are `String`, `bool`, `int` or `List<String>`.
  /// Throws a `PlatformException` when a settings file is corrupt.
  Future<Map<String, Object?>> readSettings();
}

/// Reads the old data through the native method channel.
class ChannelLegacySource implements LegacySource {
  static const _channel = MethodChannel('io.github.skooyo.koban/legacy');

  @override
  Future<String> databasePath() async =>
      (await _channel.invokeMethod<String>('databasePath'))!;

  @override
  Future<Map<String, Object?>> readSettings() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('readSettings') ?? {};
    return {
      for (final e in raw.entries)
        e.key: e.value is List ? List<String>.from(e.value! as List) : e.value,
    };
  }
}
