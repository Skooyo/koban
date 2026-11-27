import 'dart:async';
import 'dart:developer' as developer;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_services.dart';
import '../../data/database.dart';
import '../../data/people_repository.dart';
import '../../data/qr_store.dart';
import '../../data/user_error.dart';
import '../../rules/people_math.dart';

/// What people owe you and what you owe, and how many people stand on each side.
typedef PeopleTotals = ({
  Decimal owed,
  int owedCount,
  Decimal owe,
  int oweCount,
});

/// The state of the People tab: the people in groups, the search and the past splits.
/// A port of `PeopleViewModel.kt`.
class PeopleViewModel extends ChangeNotifier {
  PeopleViewModel(this._s) {
    _subs.add(
      _s.people.watchPeople().listen((people) {
        _people = people;
        notifyListeners();
      }, onError: _logError),
    );
    _subs.add(
      _s.splits.watchBills().listen((bills) {
        _bills = bills;
        notifyListeners();
      }, onError: _logError),
    );
  }

  static void _logError(Object e, StackTrace s) =>
      developer.log('Load failed', name: 'People', error: e, stackTrace: s);

  final AppServices _s;
  final List<StreamSubscription<Object?>> _subs = [];
  List<PersonSummary> _people = const [];
  List<SplitBill> _bills = const [];
  var _query = '';

  String get query => _query;

  void setQuery(String q) {
    _query = q;
    notifyListeners();
  }

  /// The groups that have people, in display order. The search filters the names.
  List<(PeopleGroup, List<PersonSummary>)> get sections {
    final key = PeopleMath.normalizedName(_query);
    final shown = _people
        .where((p) => PeopleMath.normalizedName(p.person.name).contains(key))
        .toList();
    return [
      for (final group in PeopleGroup.values)
        (
          group,
          [
            for (final p in shown)
              if (PeopleMath.group(p.balance) == group) p,
          ],
        ),
    ].where((e) => e.$2.isNotEmpty).toList();
  }

  /// The totals of everyone. The search does not change them.
  PeopleTotals get totals {
    var owed = Decimal.zero;
    var owe = Decimal.zero;
    var owedCount = 0;
    var oweCount = 0;
    for (final p in _people) {
      switch (p.balance) {
        case PaysYou(:final amount):
          owed += amount;
          owedCount++;
        case YouPay(:final amount):
          owe += amount;
          oweCount++;
        default:
      }
    }
    return (owed: owed, owedCount: owedCount, owe: owe, oweCount: oweCount);
  }

  List<SplitBill> get bills => _bills;

  /// Opens the photo picker. It returns the path of the picked picture, or null on a cancel.
  Future<String?> pickQr() => _s.pickImage();

  /// Deletes the cached copy of a picked picture that the owner did not use.
  Future<void> discardPick(String path) async {
    try {
      await deleteCachedPick(await _s.cacheDir(), path);
    } catch (e, st) {
      developer.log(
        'Delete of the picked copy failed',
        name: 'People',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Adds the person, and saves [qrPath] as the QR when it is given.
  /// Returns the id of the person. Throws a user error for a blank name.
  /// A QR that cannot be saved does not undo the add: [qrError] says why.
  Future<({String id, String? qrError})> add(
    String name, {
    String? qrPath,
  }) async {
    final id = await _s.people.addPerson(name);
    if (qrPath == null) return (id: id, qrError: null);
    String? qrError;
    try {
      await _s.people.setQr(id, qrPath);
    } on KobanUserError catch (e) {
      qrError = e.message;
    } catch (e, st) {
      developer.log('QR save failed', name: 'People', error: e, stackTrace: st);
      qrError = 'Could not save the QR.';
    } finally {
      try {
        await deleteCachedPick(await _s.cacheDir(), qrPath);
      } catch (e, st) {
        developer.log(
          'Delete of the picked copy failed',
          name: 'People',
          error: e,
          stackTrace: st,
        );
      }
    }
    return (id: id, qrError: qrError);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
