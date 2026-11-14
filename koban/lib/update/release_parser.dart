import 'dart:convert';

/// An APK that is newer than the installed app.
class AvailableUpdate {
  const AvailableUpdate({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.apkSize,
    required this.notes,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final int apkSize;
  final String notes;

  @override
  bool operator ==(Object other) =>
      other is AvailableUpdate &&
      other.versionCode == versionCode &&
      other.versionName == versionName &&
      other.apkUrl == apkUrl &&
      other.apkSize == apkSize &&
      other.notes == notes;

  @override
  int get hashCode =>
      Object.hash(versionCode, versionName, apkUrl, apkSize, notes);
}

abstract final class ReleaseParser {
  static final _apkName = RegExp(r'^koban-(\d+)\.apk$');

  /// Reads the GitHub "latest release" JSON. Returns null when nothing is
  /// newer, there is no APK asset, or the JSON is bad.
  static AvailableUpdate? parseLatest(String json, int currentVersionCode) {
    try {
      final root = jsonDecode(json) as Map<String, dynamic>;
      final assets = root['assets'] as List<dynamic>;
      int? bestCode;
      Map<String, dynamic>? best;
      for (final a in assets) {
        final asset = a as Map<String, dynamic>;
        final m = _apkName.firstMatch(asset['name'] as String);
        final code = m == null ? null : int.tryParse(m.group(1)!);
        if (code == null || code > 0x7fffffff) continue;
        if (bestCode == null || code > bestCode) {
          bestCode = code;
          best = asset;
        }
      }
      if (bestCode == null || best == null || bestCode <= currentVersionCode) {
        return null;
      }
      final tag = root['tag_name'] as String;
      final body = root['body'];
      final notes = body == null ? '' : body as String;
      return AvailableUpdate(
        versionCode: bestCode,
        versionName: tag.startsWith('v') ? tag.substring(1) : tag,
        apkUrl: best['browser_download_url'] as String,
        apkSize: best['size'] as int,
        notes: notes.length > 500 ? notes.substring(0, 500) : notes,
      );
    } catch (_) {
      return null;
    }
  }
}
