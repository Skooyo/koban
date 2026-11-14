import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../capture/capture_host.dart';
import '../capture/listener_control.dart';
import '../capture/payment_apps.dart';
import '../data/activity_selection.dart';
import '../data/category_repository.dart';
import '../data/database.dart';
import '../data/expense_repository.dart';
import '../data/external_writes.dart';
import '../data/legacy_import.dart';
import '../data/merchant_category_repository.dart';
import '../data/open_database.dart';
import '../data/payment_checks.dart';
import '../data/pending_payment_repository.dart';
import '../data/settings_store.dart';
import '../data/split_repository.dart';
import '../device/device_control.dart';
import '../rules/periods.dart';

/// The database, the settings and the repositories of the app.
/// The app makes one at the start and keeps it until the process stops.
class AppServices {
  AppServices({
    required this.db,
    required this.settings,
    required this.importResult,
    required this.listener,
    required this.paymentApps,
    required this.captureHost,
    required this.device,
    this.now = DateTime.now,
    Duration checkHold = const Duration(milliseconds: 4000),
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
    pending = PendingPaymentRepository(db, now: nowMs);
    paymentChecks = PaymentChecks(
      db: db,
      pending: pending,
      expenses: expenses,
      now: nowMs,
      hold: checkHold,
    );
    externalWrites = ExternalWrites(db);
    final today = now();
    activitySelection = ActivitySelection(YearMonth(today.year, today.month));
  }

  final KobanDatabase db;
  final KobanSettings settings;

  /// The result of the 0.1.1 import at this app start.
  final ImportResult importResult;
  final ListenerControl listener;
  final PaymentApps paymentApps;
  final CaptureHost captureHost;
  final DeviceControl device;

  /// The clock. Every time in the app comes from here.
  final DateTime Function() now;

  late final CategoryRepository categories;
  late final MerchantCategoryRepository merchants;
  late final SplitRepository splits;
  late final ExpenseRepository expenses;
  late final PendingPaymentRepository pending;
  late final PaymentChecks paymentChecks;

  /// Shows the cards of the capture engine. The app starts it in front and stops it when hidden.
  late final ExternalWrites externalWrites;
  late final ActivitySelection activitySelection;

  /// True when the owner is in a group. Milestone 5 sets it. Until then it is always false.
  final ValueListenable<bool> inGroups = ValueNotifier(false);

  /// Opens the database (and imports the 0.1.1 data one time), loads the settings
  /// and adds the default categories to an empty database.
  static Future<AppServices> start() async {
    final (db, importResult) = await openKobanDatabase();
    final captureHost = ChannelCaptureHost();
    final services = AppServices(
      db: db,
      settings: await KobanSettings.load(SharedPreferencesAsync()),
      importResult: importResult,
      listener: ListenerControl(),
      paymentApps: PaymentApps(SharedPreferencesAsync(), captureHost),
      captureHost: captureHost,
      device: DeviceControl(),
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
