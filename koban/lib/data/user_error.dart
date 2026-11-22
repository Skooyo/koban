import 'package:flutter/foundation.dart';

/// An error whose [message] a screen shows to the user.
/// It replaces the Kotlin `IllegalArgumentException` and `IllegalStateException`
/// messages of the 0.1.1 repositories.
class KobanUserError implements Exception {
  const KobanUserError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The text a screen shows when its data cannot load.
const loadFailedMessage =
    'Koban could not load your data. Close Koban and open it again.';

/// A view-model whose data streams can fail. Give [onLoadError] to each `listen`,
/// so a failed load shows [loadFailedMessage] and not an empty screen.
mixin LoadErrors on ChangeNotifier {
  String? _loadError;

  /// [loadFailedMessage] after a stream failed, else null.
  String? get loadError => _loadError;

  /// The `onError` of the data streams. The log has the error type only.
  void onLoadError(Object e, StackTrace s) {
    debugPrint('Koban: load failed (${e.runtimeType})');
    _loadError = loadFailedMessage;
    notifyListeners();
  }
}
