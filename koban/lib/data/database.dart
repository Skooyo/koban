import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../rules/types.dart';
import 'converters.dart';

part 'database.g.dart';

/// The 11 table names in the order of the old Room database.
/// The import copies and reports the tables in this order.
const legacyTableOrder = <String>[
  'expenses',
  'categories',
  'merchant_category_map',
  'pending_payments',
  'dropped_notifications',
  'split_bills',
  'split_items',
  'split_people',
  'split_item_shares',
  'split_debts',
  'owed_items',
];

/// The Koban database. Its tables equal Room version 11, so the import is a copy.
@DriftDatabase(include: {'schema.drift'})
class KobanDatabase extends _$KobanDatabase {
  KobanDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}
