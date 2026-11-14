import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../capture/listener_control.dart';
import '../data/activity_selection.dart';
import '../data/category_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/legacy_import.dart';
import '../data/merchant_category_repository.dart';
import '../data/open_database.dart';
import '../data/settings_store.dart';
import '../data/split_repository.dart';
import '../rules/periods.dart';

/// The database, the settings and the repositories of the app.
/// The app makes one at the start and keeps it until the process stops.
class AppServices {
  AppServices({
    required this.db,
    required this.settings,
    required this.importResult,
    required this.listener,
    this.now = DateTime.now,
  }) {
    int nowMs() => now().millisecondsSinceEpoch;
    categories = CategoryRepository(db);
    merchants = MerchantCategoryRepository(db, now: nowMs);
    splits = SplitRepository(db, now: nowMs);
    expenses = ExpenseRepository(
      db,
      categories: categories,
      merchants: merchants,
      splits: splits,
      now: now,
    );
    final today = now();
    activitySelection = ActivitySelection(YearMonth(today.year, today.month));
  }

  final KobanDatabase db;
  final KobanSettings settings;

  /// The result of the 0.1.1 import at this app start.
  final ImportResult importResult;
  final ListenerControl listener;

  /// The clock. Every time in the app comes from here.
  final DateTime Function() now;

  late final CategoryRepository categories;
  late final MerchantCategoryRepository merchants;
  late final SplitRepository splits;
  late final ExpenseRepository expenses;
  late final ActivitySelection activitySelection;

  /// True when the owner is in a group. Milestone 5 sets it. Until then it is always false.
  final ValueListenable<bool> inGroups = ValueNotifier(false);

  /// Opens the database (and imports the 0.1.1 data one time), loads the settings
  /// and adds the default categories to an empty database.
  static Future<AppServices> start() async {
    final (db, importResult) = await openKobanDatabase();
    final services = AppServices(
      db: db,
      settings: await KobanSettings.load(SharedPreferencesAsync()),
      importResult: importResult,
      listener: ListenerControl(),
    );
    await services.categories.seedIfEmpty();
    return services;
  }
}

/// Gives the [AppServices] to the widgets below it.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
