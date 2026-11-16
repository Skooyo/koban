import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../app/app_services.dart';
import '../../data/database.dart';
import '../../data/people_repository.dart';
import '../../data/split_repository.dart';
import '../../data/undoable.dart';
import '../../data/user_error.dart';

const _tryAgain = 'Try again in a moment.';
const _failed = 'Could not save the change. Try again.';

/// The split debt that the owner marks paid, with the received payments that can match it.
@immutable
class DebtPayment {
  const DebtPayment(this.debt, this.candidates);

  final OpenDebtView debt;
  final List<Expense> candidates;
}

/// The state and the actions of the person page. A port of `PersonViewModel.kt`.
/// It runs one action at a time. A tap during an action sends "Try again in a moment.".
class PersonViewModel extends ChangeNotifier {
  PersonViewModel(this._s, this.personId) {
    _sub = _s.people.watchPerson(personId).listen((d) {
      _detail = d;
      _gone = d == null;
      notifyListeners();
    }, onError: (Object e, StackTrace s) => _log('Load failed', e, s));
  }

  final AppServices _s;
  final String personId;
  late final StreamSubscription<PersonDetail?> _sub;
  final _messages = StreamController<String>();
  var _disposed = false;

  PersonDetail? _detail;
  bool _gone = false;
  int _qrVersion = 0;
  DebtPayment? _paying;
  bool _busy = false;
  bool _picking = false;

  PersonDetail? get detail => _detail;

  /// True when the person is missing or archived, for example right after Delete person.
  bool get gone => _gone;

  /// It goes up after each QR import. The file path stays the same, so the screen reloads on this.
  int get qrVersion => _qrVersion;
  DebtPayment? get paying => _paying;

  /// True while an action runs.
  bool get busy => _busy;

  /// True while the photo picker is open.
  bool get picking => _picking;

  /// The messages for the snackbar. Only one listener.
  Stream<String> get messages => _messages.stream;

  /// Shows a delete that the owner can take back: the message, and what Undo runs.
  /// The screen sets it. A delete that closes the page still calls it after the page is gone.
  void Function(String message, Undoable undo)? onUndo;

  void showMessage(String message) {
    if (!_disposed) _messages.add(message);
  }

  // Dialog actions: they throw, and the dialog shows the message.
  Future<void> rename(String name) => _s.people.renamePerson(personId, name);

  Future<void> addItem(String description, Decimal amount, int itemDate) =>
      _s.people.addOwedItem(personId, description, amount, itemDate);

  Future<void> updateItem(OwedItem item) => _s.people.updateOwedItem(item);

  Future<void> addOwedToMe(String description, Decimal amount, int itemDate) =>
      _s.people.addOwedToMe(personId, description, amount, itemDate);

  Future<void> updateOwedToMe(
    String debtId,
    String description,
    Decimal amount,
    int itemDate,
  ) => _s.people.updateOwedToMe(debtId, description, amount, itemDate);

  /// The delete shows [message] with Undo on [undos].
  void deleteItem(String id, String message) =>
      _runUndo(message, () => _s.people.deleteOwedItem(id));

  void markItemPaid(String id) => _run(() => _s.people.markOwedItemPaid(id));

  void deleteOwedToMe(String debtId, String message) =>
      _runUndo(message, () => _s.people.deleteOwedToMe(debtId));

  void delete(String message) =>
      _runUndo(message, () => _s.people.archivePerson(personId));

  /// Opens the photo picker and imports the picked picture as the QR. A cancel does nothing.
  void pickQr() => unawaited(_pickQr());

  Future<void> _pickQr() async {
    if (_picking) return;
    _picking = true;
    String? path;
    try {
      path = await _s.pickImage();
    } catch (e, s) {
      _log('Pick failed', e, s);
      showMessage(_failed);
      return;
    } finally {
      _picking = false;
    }
    if (path == null) return;
    final picked = path;
    _run(() async {
      try {
        await _s.people.setQr(personId, picked);
        _qrVersion++;
        _notify();
      } finally {
        await _deleteCachedCopy(picked);
      }
    });
  }

  /// The picker copies each picture into the app cache. Delete that copy, and never a file outside the cache.
  Future<void> _deleteCachedCopy(String path) async {
    try {
      final cache = await _s.cacheDir();
      if (!p.isWithin(cache.path, path)) return;
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (e, s) {
      _log('Delete of the picked copy failed', e, s);
    }
  }

  /// Saves the QR to the gallery. Old Android versions ask for the storage permission first.
  void saveQrToGallery() => _run(() async {
    final device = _s.device;
    if (!await device.storageAllowed() &&
        !await device.requestStoragePermission()) {
      showMessage('Allow storage access to save the QR.');
      return;
    }
    await _s.people.saveQrToGallery(personId);
    showMessage('Saved to gallery. Open your bank app and pick it.');
  });

  void settleUp() => _run(() => _s.people.settleUp(personId));

  void confirmSettle() => _run(() async {
    if (!await _s.people.confirmSettleSuggestion(personId)) {
      showMessage(
        'That payment no longer matches. Check the amounts and settle up by hand.',
      );
    }
  });

  void dismissSettle() =>
      _run(() => _s.people.dismissSettleSuggestion(personId));

  void startPaying(OpenDebtView debt) => _run(() async {
    final candidates = await _s.splits.repaymentCandidates(debt.debt.id);
    _paying = DebtPayment(debt, candidates);
    _notify();
  });

  void cancelPaying() {
    _paying = null;
    _notify();
  }

  /// A null [expenseId] means paid in cash. It returns false when nothing starts:
  /// no debt is being paid, or another action runs. Then [paying] stays, so the choice stays open.
  bool markDebtPaid(String? expenseId) {
    final debtId = _paying?.debt.debt.id;
    if (debtId == null) return false;
    if (_busy) {
      showMessage(_tryAgain);
      return false;
    }
    _paying = null;
    _notify();
    _run(() => _s.splits.markPaid(debtId, expenseId));
    return true;
  }

  void confirmDebtSuggestion(String debtId) =>
      _run(() => _s.splits.confirmSuggestion(debtId));

  void dismissDebtSuggestion(String debtId) =>
      _run(() => _s.splits.dismissSuggestion(debtId));

  void _runUndo(String message, Future<Undoable?> Function() action) =>
      _run(() async {
        final undo = await action();
        if (undo != null) onUndo?.call(message, undo);
      });

  /// Runs one action at a time. A [KobanUserError] sends its message; another error sends a general one.
  void _run(Future<void> Function() action) {
    if (_busy) {
      showMessage(_tryAgain);
      return;
    }
    _busy = true;
    unawaited(() async {
      try {
        await action();
      } on KobanUserError catch (e) {
        showMessage(e.message);
      } catch (e, s) {
        _log('Action failed', e, s);
        showMessage(_failed);
      } finally {
        _busy = false;
      }
    }());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static void _log(String message, Object e, StackTrace s) =>
      developer.log(message, name: 'Person', error: e, stackTrace: s);

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub.cancel());
    unawaited(_messages.close());
    super.dispose();
  }
}
