import 'dart:async';
import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../data/database.dart';
import '../../data/people_repository.dart';
import '../../data/qr_store.dart';
import '../../data/split_repository.dart';
import '../../data/undoable.dart';
import '../../data/user_error.dart';

const _tryAgain = 'Try again in a moment.';
const storageRefused = 'Koban cannot save to the gallery.';
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
class PersonViewModel extends ChangeNotifier with LoadErrors {
  PersonViewModel(this._s, this.personId) {
    _sub = _s.people.watchPerson(personId).listen((d) {
      _detail = d;
      _gone = d == null;
      notifyListeners();
      unawaited(_readQrDate(d?.person.qrPath));
    }, onError: onLoadError);
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

  int? _qrAddedAt;

  /// When the QR was added (epoch ms), or null with no QR. It loads after the page does,
  /// because it reads the file.
  int? get qrAddedAt => _qrAddedAt;

  Future<void> _readQrDate(String? path) async {
    try {
      final added = await _s.people.qrAddedAt(path);
      if (added == _qrAddedAt || _disposed) return;
      _qrAddedAt = added;
      notifyListeners();
    } catch (e, s) {
      _log('Read of the QR date failed', e, s);
    }
  }

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

  /// The mark shows [message] with Undo on [undos].
  void markItemPaid(String id, String message) =>
      _runUndo(message, () => _s.people.markOwedItemPaid(id));

  void deleteOwedToMe(String debtId, String message) =>
      _runUndo(message, () => _s.people.deleteOwedToMe(debtId));

  void delete(String message) =>
      _runUndo(message, () => _s.people.archivePerson(personId));

  /// Opens the photo picker. It returns the path of the picked picture, or null on a cancel
  /// or a failure. The caller shows the picture first, then calls [replaceQr] or [discardPick].
  Future<String?> pickQr() async {
    if (_picking) return null;
    _picking = true;
    _qrError = null;
    try {
      return await _s.pickImage();
    } catch (e, s) {
      _log('Pick failed', e, s);
      _failQr(_failed);
      return null;
    } finally {
      _picking = false;
    }
  }

  /// True after a refused storage permission, until the next save. The QR sheet shows
  /// [storageRefused] with an "Open settings" button.
  bool get storageDenied => _storageRefused;
  bool _storageRefused = false;

  /// The message of the last QR failure, or null. A snackbar can sit behind an open sheet,
  /// so the Edit sheet also shows this text.
  String? get qrError => _qrError;
  String? _qrError;

  void _failQr(String message) {
    _qrError = message;
    showMessage(message);
    _notify();
  }

  /// Saves the picked picture at [picked] as the QR and deletes the cached copy.
  /// [undo] is the way back to the old picture, or null when there was none.
  Future<({bool saved, Undoable? undo})> replaceQr(String picked) async {
    if (_busy) {
      showMessage(_tryAgain);
      await _deleteCachedCopy(picked);
      return (saved: false, undo: null);
    }
    _busy = true;
    _qrError = null;
    try {
      final undo = await _s.people.replaceQr(personId, picked);
      _qrVersion++;
      _notify();
      return (saved: true, undo: undo == null ? null : _bumping(undo));
    } on KobanUserError catch (e) {
      _failQr(e.message);
    } catch (e, s) {
      _log('Replace QR failed', e, s);
      _failQr(_failed);
    } finally {
      _busy = false;
      await _deleteCachedCopy(picked);
    }
    return (saved: false, undo: null);
  }

  /// Removes the QR. The snackbar has Undo.
  void removeQr() => _runUndo('QR removed', () async {
    final undo = await _s.people.removeQr(personId);
    _qrVersion++;
    _notify();
    return undo == null ? null : _bumping(undo);
  });

  /// An undo that also makes the page read the QR file again.
  Undoable _bumping(Undoable u) => Undoable(
    undo: () async {
      await u.undo();
      _qrVersion++;
      _notify();
    },
  );

  /// Deletes the cached copy of a picture that the owner did not use.
  Future<void> discardPick(String path) => _deleteCachedCopy(path);

  Future<void> _deleteCachedCopy(String path) async {
    try {
      await deleteCachedPick(await _s.cacheDir(), path);
    } catch (e, s) {
      _log('Delete of the picked copy failed', e, s);
    }
  }

  /// Saves the QR to the gallery. Old Android versions ask for the storage permission first.
  void saveQrToGallery() => _run(() async {
    final device = _s.device;
    _storageRefused = false;
    if (!await device.storageAllowed() &&
        !await device.requestStoragePermission()) {
      // The QR sheet covers the snackbar, so the sheet shows this with "Open settings".
      _storageRefused = true;
      showMessage(storageRefused);
      _notify();
      return;
    }
    _notify();
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
