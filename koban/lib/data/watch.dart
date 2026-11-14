import 'dart:async';

import 'package:drift/drift.dart';

import 'database.dart';

/// Emit the result of [load] now. Emit it again after each write to one of [tables].
/// It is the Room `Flow` of a query that reads several tables.
///
/// The stream subscribes to the table updates before the first [load].
/// A write that lands while a load runs starts one more load, so no write is missed.
/// Writes that land during one load share the next load.
Stream<T> watchTables<T>(
  KobanDatabase db,
  Set<ResultSetImplementation> tables,
  Future<T> Function() load,
) {
  late final StreamController<T> controller;
  StreamSubscription<void>? subscription;
  var cancelled = false;
  var loading = false;
  var dirty = false;

  Future<void> run() async {
    if (loading) {
      dirty = true;
      return;
    }
    loading = true;
    try {
      do {
        dirty = false;
        final value = await load();
        if (cancelled) return;
        controller.add(value);
      } while (dirty && !cancelled);
    } catch (error, stack) {
      if (!cancelled) controller.addError(error, stack);
    } finally {
      loading = false;
    }
  }

  controller = StreamController<T>(
    onListen: () {
      subscription = db
          .tableUpdates(TableUpdateQuery.onAllTables(tables))
          .listen((_) => run());
      run();
    },
    onCancel: () {
      cancelled = true;
      return subscription?.cancel();
    },
  );
  return controller.stream;
}
