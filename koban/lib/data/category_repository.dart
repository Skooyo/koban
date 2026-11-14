import 'package:drift/drift.dart';

import 'database.dart';
import 'ids.dart';

/// The categories. A port of `CategoryRepository.kt` and `DefaultCategories.kt`.
class CategoryRepository {
  CategoryRepository(this._db);

  final KobanDatabase _db;

  static const uncategorizedName = 'Uncategorized';
  static const uncategorizedColor = '#9E9E9E';

  /// The 7 built-in categories.
  static const defaults = <Category>[
    Category(
      id: 'food',
      name: 'Food & Dining',
      colorHex: '#E53935',
      isDefault: true,
    ),
    Category(
      id: 'transport',
      name: 'Transport',
      colorHex: '#1E88E5',
      isDefault: true,
    ),
    Category(
      id: 'shopping',
      name: 'Shopping',
      colorHex: '#8E24AA',
      isDefault: true,
    ),
    Category(
      id: 'bills',
      name: 'Bills & Utilities',
      colorHex: '#FB8C00',
      isDefault: true,
    ),
    Category(
      id: 'entertainment',
      name: 'Entertainment',
      colorHex: '#43A047',
      isDefault: true,
    ),
    Category(
      id: 'health',
      name: 'Health',
      colorHex: '#00ACC1',
      isDefault: true,
    ),
    Category(id: 'other', name: 'Other', colorHex: '#757575', isDefault: true),
  ];

  /// All categories, ordered by name.
  Stream<List<Category>> watchAll() => _db.allCategories().watch();

  Future<List<Category>> getAll() => _db.allCategories().get();

  /// Adds the built-in categories when the table is empty.
  Future<void> seedIfEmpty() async {
    if (await _db.categoryCount().getSingle() == 0) {
      await _db.batch(
        (b) => b.insertAll(
          _db.categories,
          defaults,
          mode: InsertMode.insertOrReplace,
        ),
      );
    }
  }

  /// A blank name adds nothing.
  Future<void> addCategory(String name, String colorHex) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _db
        .into(_db.categories)
        .insert(
          Category(
            id: newId(),
            name: trimmed,
            colorHex: colorHex,
            isDefault: false,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// Deletes an own category. A built-in category stays. It returns true when a row went.
  Future<bool> deleteCategory(String id) async =>
      await _db.deleteCustomCategory(id) > 0;

  Future<Category?> getById(String? id) async =>
      id == null ? null : await _db.categoryById(id).getSingleOrNull();
}
