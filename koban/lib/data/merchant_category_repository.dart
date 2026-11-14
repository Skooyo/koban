import 'package:drift/drift.dart';

import 'database.dart';

/// The category that the owner chose for each shop. A port of `MerchantCategoryRepository.kt`.
class MerchantCategoryRepository {
  MerchantCategoryRepository(this._db, {required this._now});

  final KobanDatabase _db;
  final int Function() _now;

  /// The trimmed, lower-case name. A blank or null name gives null.
  String? normalizeKey(String? merchant) {
    final key = merchant?.trim().toLowerCase();
    return key == null || key.isEmpty ? null : key;
  }

  Future<String?> categoryIdForMerchant(String? merchant) async {
    final key = normalizeKey(merchant);
    if (key == null) return null;
    return (await _db.merchantMappingByKey(key).getSingleOrNull())?.categoryId;
  }

  /// Remembers the category for the shop. A blank shop or a null category saves nothing.
  Future<void> saveMapping(String? merchant, String? categoryId) async {
    final key = normalizeKey(merchant);
    if (key == null || categoryId == null) return;
    await _db
        .into(_db.merchantCategoryMap)
        .insert(
          MerchantCategoryMapData(
            merchantKey: key,
            displayName: merchant!.trim(),
            categoryId: categoryId,
            updatedAt: _now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}
