import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/settings_store.dart';
import '../online/online_http.dart';
import 'release_parser.dart';
import 'update_installer.dart';
import 'update_schedule.dart';

const releasesUrl = 'https://api.github.com/repos/Skooyo/koban/releases/latest';

const _failedInstall = 'Update failed. Try again later.';

/// What the update dialog and the Settings row show.
sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();

  @override
  bool operator ==(Object other) => other is UpdateIdle;

  @override
  int get hashCode => 1;
}

class UpdateUpToDate extends UpdateState {
  const UpdateUpToDate();

  @override
  bool operator ==(Object other) => other is UpdateUpToDate;

  @override
  int get hashCode => 2;
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.update);

  final AvailableUpdate update;

  @override
  bool operator ==(Object other) =>
      other is UpdateAvailable && other.update == update;

  @override
  int get hashCode => update.hashCode;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading();

  @override
  bool operator ==(Object other) => other is UpdateDownloading;

  @override
  int get hashCode => 4;
}

class UpdateInstalling extends UpdateState {
  const UpdateInstalling();

  @override
  bool operator ==(Object other) => other is UpdateInstalling;

  @override
  int get hashCode => 5;
}

/// With [retry] set, "OK" goes back to [UpdateAvailable] for that update.
class UpdateFailed extends UpdateState {
  const UpdateFailed(this.message, {this.retry});

  final String message;
  final AvailableUpdate? retry;

  @override
  bool operator ==(Object other) =>
      other is UpdateFailed && other.message == message && other.retry == retry;

  @override
  int get hashCode => Object.hash(message, retry);
}

/// Checks for a new release, downloads the APK and gives it to the installer.
/// A port of `UpdateRepository.kt` of 0.1.1.
class UpdateRepository {
  UpdateRepository({
    required this._http,
    required this._settings,
    required UpdateInstaller installer,
    required this._cacheDir,
    required this._now,
    this.noDataLimit = const Duration(seconds: 60),
  }) : _installer = installer {
    installer.onStatus(_onInstallStatus);
  }

  /// The longest wait for data of a download. A test gives a shorter one.
  final Duration noDataLimit;

  final http.Client _http;
  final KobanSettings _settings;
  final UpdateInstaller _installer;

  /// Resolved at each download, so the repository needs no folder at the start.
  final Future<Directory> Function() _cacheDir;
  final DateTime Function() _now;

  final _state = ValueNotifier<UpdateState>(const UpdateIdle());

  /// The update of the last download, so "Close" on installing can go back to the update.
  AvailableUpdate? _inProgress;

  ValueListenable<UpdateState> get state => _state;

  bool get _busy =>
      _state.value is UpdateDownloading || _state.value is UpdateInstalling;

  /// Checks GitHub for a new release. Does nothing while busy or when the schedule says no.
  Future<void> check({required bool manual}) async {
    final now = _now().millisecondsSinceEpoch;
    if (_busy) return;
    if (!UpdateSchedule.shouldCheck(
      online: _settings.onlineFeatures.value,
      lastCheckMs: await _settings.lastUpdateCheck(),
      nowMs: now,
      manual: manual,
    )) {
      return;
    }
    UpdateState next;
    try {
      final versionCode = await _installer.versionCode();
      // Only these two headers: no app version, no account ID.
      final response = await TimeoutClient(_http).get(
        Uri.parse(releasesUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Koban-Android',
        },
      );
      // Any answer counts, so a 403 or 404 waits a day.
      await _settings.setLastUpdateCheck(now);
      if (response.statusCode != 200) {
        next = _failedCheck(manual);
      } else {
        final update = ReleaseParser.parseLatest(
          utf8.decode(response.bodyBytes),
          versionCode,
        );
        next = update != null
            ? UpdateAvailable(update)
            : manual
            ? const UpdateUpToDate()
            : const UpdateIdle();
      }
    } catch (e) {
      debugPrint('Koban: update check failed (${e.runtimeType})');
      next = _failedCheck(manual);
    }
    if (!_busy) _state.value = next;
  }

  UpdateState _failedCheck(bool manual) => manual
      ? const UpdateFailed('Could not check for updates. Try again later.')
      : const UpdateIdle();

  /// True from the tap on Update until the permission check passes or the call ends.
  var _starting = false;

  /// Downloads the APK of the available update and installs it.
  Future<void> downloadAndInstall() async {
    // Only from available: a second tap while busy does nothing.
    final available = _state.value;
    if (available is! UpdateAvailable || _starting) return;
    final update = available.update;
    // Set before the first await, so two quick taps start one download.
    _starting = true;
    File? file;
    try {
      final allowed = await _installer.canInstall();
      // Later or Back during the call closed the dialog: do not start.
      if (!identical(_state.value, available)) return;
      if (!allowed) {
        // If Android stops the app after the grant, the next start checks again.
        await _settings.setLastUpdateCheck(0);
        try {
          await _installer.openInstallSettings();
        } catch (e) {
          debugPrint('Koban: install settings failed (${e.runtimeType})');
        }
        _state.value = UpdateFailed(
          'Allow Koban to install apps, then tap Update again.',
          retry: update,
        );
        return;
      }
      _state.value = const UpdateDownloading();
      _inProgress = update;
      _starting = false;
      if (!_settings.onlineFeatures.value) {
        _state.value = const UpdateIdle();
        return;
      }
      final dir = Directory('${(await _cacheDir()).path}/updates');
      if (dir.existsSync()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      file = File('${dir.path}/koban-${update.versionCode}.apk');
      await _download(update.apkUrl, file);
      _state.value = const UpdateInstalling();
      await _installer.install(file.path, update.versionCode);
    } catch (e) {
      debugPrint('Koban: update failed (${e.runtimeType})');
      _state.value = UpdateFailed(_failedInstall, retry: update);
    } finally {
      _starting = false;
      // The session holds its own copy, so the file is not needed after the call.
      try {
        if (file != null && file.existsSync()) file.deleteSync();
      } catch (e) {
        debugPrint('Koban: update file delete failed (${e.runtimeType})');
      }
      // A failure must not leave the state on downloading.
      if (_state.value is UpdateDownloading) _state.value = const UpdateIdle();
    }
  }

  /// Downloads with no total time limit. 60 s without data is an error,
  /// and the wait for the response headers counts as well.
  Future<void> _download(String url, File file) async {
    final noData = noDataLimit;
    final abort = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      Uri.parse(url),
      abortTrigger: abort.future,
    )..headers['User-Agent'] = 'Koban-Android';
    try {
      final response = await _http.send(request).timeout(noData);
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream.timeout(noData)) {
          received += chunk.length;
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      final expected = response.contentLength;
      if (expected != null && received < expected) {
        throw const HttpException('The download ended early');
      }
    } catch (_) {
      // Closes the connection and the unread body.
      if (!abort.isCompleted) abort.complete();
      rethrow;
    }
  }

  /// Closes the dialog. Available: idle. Installing: back to the update, because the
  /// confirm screen can fail to open or be left with Home, and then no status arrives.
  /// Failed with a retry: back to the update. Other failed: idle.
  void later() {
    final s = _state.value;
    _state.value = switch (s) {
      UpdateInstalling() =>
        _inProgress == null
            ? const UpdateIdle()
            : UpdateAvailable(_inProgress!),
      UpdateFailed(:final retry) =>
        retry == null ? const UpdateIdle() : UpdateAvailable(retry),
      _ => const UpdateIdle(),
    };
  }

  void _onInstallStatus(InstallStatus status, String? message) {
    switch (status) {
      // The confirm screen is open. The next status comes after the user answers.
      case InstallStatus.pendingUserAction:
        break;
      // Android stops and restarts the app. Nothing more to do.
      case InstallStatus.success:
        _state.value = const UpdateIdle();
      case InstallStatus.failure:
        debugPrint('Koban: install failed');
        _state.value = UpdateFailed(_failedInstall, retry: _inProgress);
    }
  }
}
