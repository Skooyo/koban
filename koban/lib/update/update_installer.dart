import 'package:flutter/services.dart';

/// The result of the Android package installer.
enum InstallStatus { success, pendingUserAction, failure }

/// The file is not the Koban APK of the expected version. Native code made no install session.
class NotKobanApk implements Exception {}

/// The native installer of updates.
abstract interface class UpdateInstaller {
  /// The version code of the installed app.
  Future<int> versionCode();

  /// True when the phone lets Koban install apps.
  Future<bool> canInstall();

  /// Opens the "Install unknown apps" page of Koban.
  Future<void> openInstallSettings();

  /// Gives the APK at [path] to the package installer.
  /// Throws [NotKobanApk] when the file is not the Koban APK with [versionCode].
  Future<void> install(String path, int versionCode);

  /// Sets the handler for the installer status. A new handler replaces the old one.
  void onStatus(void Function(InstallStatus status, String? message) handler);
}

class ChannelUpdateInstaller implements UpdateInstaller {
  ChannelUpdateInstaller([
    this._channel = const MethodChannel('io.github.skooyo.koban/update'),
  ]);

  final MethodChannel _channel;

  @override
  Future<int> versionCode() async =>
      (await _channel.invokeMethod<int>('versionCode'))!;

  @override
  Future<bool> canInstall() async =>
      (await _channel.invokeMethod<bool>('canInstall'))!;

  @override
  Future<void> openInstallSettings() =>
      _channel.invokeMethod<void>('openInstallSettings');

  @override
  Future<void> install(String path, int versionCode) async {
    try {
      await _channel.invokeMethod<void>('install', {
        'path': path,
        'versionCode': versionCode,
      });
    } on PlatformException catch (e) {
      if (e.code == 'NOT_KOBAN_APK') throw NotKobanApk();
      rethrow;
    }
  }

  @override
  void onStatus(void Function(InstallStatus status, String? message) handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'installStatus') return;
      final args = call.arguments as Map<Object?, Object?>;
      final status = switch (args['status']) {
        'success' => InstallStatus.success,
        'pendingUserAction' => InstallStatus.pendingUserAction,
        _ => InstallStatus.failure,
      };
      handler(status, args['message'] as String?);
    });
  }
}
