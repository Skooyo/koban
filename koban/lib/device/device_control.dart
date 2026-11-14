import 'package:flutter/services.dart';

import '../data/user_error.dart';

/// One launcher app on the phone.
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    required this.icon,
  });

  final String packageName;
  final String label;

  /// PNG bytes, or null when the icon did not load.
  final Uint8List? icon;
}

/// Phone features of the device channel. One method for each native method.
class DeviceControl {
  DeviceControl([
    this._channel = const MethodChannel('io.github.skooyo.koban/device'),
  ]);

  final MethodChannel _channel;

  /// Launcher apps other than Koban. One row for each package. Not sorted.
  Future<List<InstalledApp>> installedApps() async {
    final rows = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'installedApps',
    );
    return [
      for (final r in rows ?? const <Map<Object?, Object?>>[])
        InstalledApp(
          packageName: r['packageName']! as String,
          label: r['label']! as String,
          icon: r['icon'] as Uint8List?,
        ),
    ];
  }

  /// The label of each package. The package name stands in when the app is not visible.
  Future<Map<String, String>> appLabels(Iterable<String> packages) async {
    final m = await _channel.invokeMapMethod<String, String>('appLabels', {
      'packages': packages.toList(),
    });
    return m ?? const {};
  }

  Future<int> sdkInt() async => (await _channel.invokeMethod<int>('sdkInt'))!;

  Future<String> versionName() async =>
      (await _channel.invokeMethod<String>('versionName'))!;

  Future<bool> notificationsAllowed() async =>
      (await _channel.invokeMethod<bool>('notificationsAllowed'))!;

  Future<bool> shouldShowNotificationRationale() async =>
      (await _channel.invokeMethod<bool>('shouldShowNotificationRationale'))!;

  /// Asks for the alerts permission. True when granted.
  Future<bool> requestNotificationPermission() async =>
      (await _channel.invokeMethod<bool>('requestNotificationPermission'))!;

  Future<void> openAppNotificationSettings() =>
      _channel.invokeMethod<void>('openAppNotificationSettings');

  Future<void> openAppInfo() => _channel.invokeMethod<void>('openAppInfo');

  Future<bool> storageAllowed() async =>
      (await _channel.invokeMethod<bool>('storageAllowed'))!;

  /// Asks for the storage permission. True when granted.
  Future<bool> requestStoragePermission() async =>
      (await _channel.invokeMethod<bool>('requestStoragePermission'))!;

  /// Saves the picture at [path] to Pictures/Koban. A picture that does not decode throws
  /// [KobanUserError] "That file isn't an image.". Another failure rethrows the
  /// [PlatformException], so the screen shows its general message, as 0.1.1 did.
  Future<void> saveImageToGallery(String path, String displayName) async {
    const notImage = "That file isn't an image.";
    try {
      await _channel.invokeMethod<String>('saveImageToGallery', {
        'path': path,
        'displayName': displayName,
      });
    } on PlatformException catch (e) {
      if (e.code == 'GALLERY' && e.message == notImage) {
        throw const KobanUserError(notImage);
      }
      rethrow;
    }
  }

  /// Opens the system share chooser with [text].
  Future<void> shareText(String text, {String chooserTitle = 'Share summary'}) =>
      _channel.invokeMethod<void>('shareText', {
        'text': text,
        'chooserTitle': chooserTitle,
      });
}
