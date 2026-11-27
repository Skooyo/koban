import 'dart:async';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../rules/amount_formatter.dart';
import '../rules/dedup_key_generator.dart';
import 'database.dart';
import 'expense_dedup.dart';
import 'expense_repository.dart';
import 'pending_payment_repository.dart';

enum ConfirmResult { saved, alreadySaved, dropped }

class _Held {
  _Held(this.ids, this.save);

  final List<String> ids;
  final bool save;
  Timer? timer;
}

/// The swipes of "Check payments": the hold for the Undo window, Undo and the commit.
/// A port of the hold part of `PendingPaymentRepository.kt`.
///
/// Only the UI isolate has this class. The capture isolate uses only
/// [PendingPaymentRepository], so it has no timers and no hidden cards.
/// Each commit is one transaction, so it is atomic across the two isolates.
class PaymentChecks {
  PaymentChecks({
    required this._db,
    required this._pending,
    required this._expenses,
    required this._now,
    this._hold = const Duration(milliseconds: 6000),
  });

  final KobanDatabase _db;
  final PendingPaymentRepository _pending;
  final ExpenseRepository _expenses;
  final int Function() _now;
  final Duration _hold;

  /// The hold and Undo window: 6000 ms (DESIGN.md; 0.1.1 had 4000 ms).
  Duration get holdWindow => _hold;

  _Held? _held;

  /// The held card and the cards whose commit runs now. They do not show.
  final Set<String> _hidden = {};
  final _hiddenChanged = StreamController<void>.broadcast();

  /// Cards that a commit deleted. They do not show while the old rows are still in a stream.
  /// An id leaves the set when the rows no longer have it.
  final Set<String> _gone = {};

  final _results = StreamController<ConfirmResult>.broadcast();
  int _running = 0;
  Completer<void>? _idle;

  /// The result of each commit that found its card.
  Stream<ConfirmResult> get results => _results.stream;

  /// Completes when no commit runs. A test seam.
  Future<void> get idle =>
      _running == 0 ? Future.value() : (_idle ??= Completer<void>()).future;

  /// The waiting payments, oldest first, without the hidden cards.
  Stream<List<PendingPayment>> watchVisible() {
    late final StreamController<List<PendingPayment>> controller;
    StreamSubscription<void>? hiddenSub;
    StreamSubscription<List<PendingPayment>>? rowsSub;
    List<PendingPayment>? rows;
    void emit() {
      final all = rows;
      if (all == null) return;
      final ids = {for (final p in all) p.id};
      _gone.retainWhere(ids.contains);
      controller.add([
        for (final p in all)
          if (!_hidden.contains(p.id) && !_gone.contains(p.id)) p,
      ]);
    }

    controller = StreamController<List<PendingPayment>>(
      onListen: () {
        hiddenSub = _hiddenChanged.stream.listen((_) => emit());
        rowsSub = _pending.watchWaiting().listen((r) {
          rows = r;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await hiddenSub?.cancel();
        await rowsSub?.cancel();
      },
    );
    return controller.stream;
  }

  Stream<int> watchVisibleCount() => watchVisible().map((l) => l.length);

  /// The number of waiting payments without the hidden cards. One fresh read of the table.
  Future<int> visibleCount() async => [
    for (final p in await _db.observePending().get())
      if (!_hidden.contains(p.id) && !_gone.contains(p.id)) p,
  ].length;

  /// Writes an edit of a card at once.
  Future<void> update(PendingPayment p) {
    final amount = AmountFormatter.toMoney(p.amount);
    return _db
        .update(_db.pendingPayments)
        .replace(
          p.copyWith(
            amount: amount,
            // A forced card keeps its key, so an edit does not bring the duplicate check back.
            dedupKey: p.dedupKey.startsWith(forcedDedupPrefix)
                ? p.dedupKey
                : DedupKeyGenerator.generate(
                    packageName: p.sourcePackage,
                    amount: amount,
                    merchant: p.merchant,
                    postTime: p.notificationPostTime,
                  ),
            edited: true,
          ),
        );
  }

  /// Holds a swipe for the Undo window, then commits it. An earlier hold of
  /// other cards commits at once. The same card again only replaces the
  /// choice and starts the window again.
  void hold(String id, {required bool save}) => holdAll([id], save: save);

  /// Holds one choice for several cards: one window, one Undo.
  void holdAll(List<String> ids, {required bool save}) {
    final previous = _held;
    _held = null;
    if (previous != null) {
      previous.timer?.cancel();
      if (!listEquals(previous.ids, ids)) _launchCommit(previous);
    }
    ids.forEach(_hide);
    final entry = _Held(ids, save);
    entry.timer = Timer(_hold, () {
      if (!identical(_held, entry)) return;
      _held = null;
      _launchCommit(entry);
    });
    _held = entry;
  }

  /// Releases the hold without a write. Returns false when nothing is held.
  bool undo() {
    final entry = _held;
    if (entry == null) return false;
    _held = null;
    entry.timer?.cancel();
    entry.ids.forEach(_show);
    return true;
  }

  /// Commits the hold now. Safe to call again and when nothing is held.
  void flushHold() {
    final entry = _held;
    if (entry == null) return;
    _held = null;
    entry.timer?.cancel();
    _launchCommit(entry);
  }

  void _hide(String id) {
    if (_hidden.add(id)) _hiddenChanged.add(null);
  }

  void _show(String id) {
    if (_hidden.remove(id)) _hiddenChanged.add(null);
  }

  void _launchCommit(_Held entry) {
    _running++;
    _commit(entry).whenComplete(() {
      if (--_running == 0) {
        _idle?.complete();
        _idle = null;
      }
    });
  }

  Future<void> _commit(_Held entry) async {
    try {
      final results = await _db.transaction(() async {
        final done = <(String, ConfirmResult)>[];
        for (final id in entry.ids) {
          final payment = await (_db.select(
            _db.pendingPayments,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
          if (payment == null) continue;
          if (entry.save) {
            final inserted = await _expenses.saveConfirmed(payment);
            // A payment covers the card in both outcomes, so the card goes.
            await _deleteCard(payment.id);
            done.add((
              id,
              inserted ? ConfirmResult.saved : ConfirmResult.alreadySaved,
            ));
            continue;
          }
          final notificationKey = payment.notificationKey;
          await _db
              .into(_db.droppedNotifications)
              .insert(
                DroppedNotification(
                  dedupKey: payment.dedupKey,
                  // Some apps use one notification key for every payment, so the key has the post time too.
                  notificationKey: notificationKey == null
                      ? null
                      : '$notificationKey@${payment.notificationPostTime}',
                  droppedAt: _now(),
                ),
                mode: InsertMode.insertOrReplace,
              );
          await _deleteCard(payment.id);
          done.add((id, ConfirmResult.dropped));
        }
        return done;
      });
      for (final (id, result) in results) {
        _gone.add(id);
        _results.add(result);
      }
    } catch (e, s) {
      // The rows stay, so the cards show again and the owner can swipe them again.
      developer.log(
        'Commit of waiting payment failed',
        name: 'PaymentChecks',
        error: e,
        stackTrace: s,
      );
    } finally {
      entry.ids.forEach(_show);
    }
  }

  Future<int> _deleteCard(String id) =>
      (_db.delete(_db.pendingPayments)..where((t) => t.id.equals(id))).go();
}
