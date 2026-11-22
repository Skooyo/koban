import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/app/koban_app.dart';
import 'package:koban/app/routes.dart';
import 'package:koban/data/user_error.dart';
import 'package:koban/main.dart' show appRoot, startFailedMessage;
import 'package:koban/screens/payment/category_sheet.dart';
import 'package:koban/theme/koban_theme.dart';
import 'package:koban/ui/undo_snack_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';
import 'activity_screen_test.dart' show inActivity, pumpActivity;
import 'check_payments_screen_test.dart' show openCheck;
import 'home_screen_test.dart' show pumpHome;
import 'payment_screen_test.dart' show addOne, openSheet;
import 'person_screen_test.dart' show settle;
import 'settings_test.dart' show pumpSettings;

void main() {
  testWidgets('the system bars follow the theme and the app sets them', (
    tester,
  ) async {
    final dark = systemBarStyle(kobanTheme(Brightness.dark));
    expect(dark.systemNavigationBarColor, const Color(0xFF141B2B));
    expect(dark.systemNavigationBarIconBrightness, Brightness.light);
    expect(dark.statusBarIconBrightness, Brightness.light);
    final light = systemBarStyle(kobanTheme(Brightness.light));
    expect(light.systemNavigationBarColor, const Color(0xFFF6F7FA));
    expect(light.systemNavigationBarIconBrightness, Brightness.dark);
    expect(light.statusBarIconBrightness, Brightness.dark);

    await pumpHome(tester, await testServices());
    final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(
      regions.map((r) => r.value.systemNavigationBarColor),
      contains(const Color(0xFFF6F7FA)),
    );
  });

  testWidgets(
    'the category sheet keeps its last row above the navigation bar',
    (tester) async {
      final s = await testServices();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);
      final categories = await s.categories.getAll();
      await pumpKoban(
        tester,
        s,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCategorySheet(
                context,
                categories: categories,
                selectedId: null,
                onPick: (_) {},
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sheet'));
      await tester.pumpAndSettle();
      final last = find.text(categories.last.name).last;
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      // The bar covers y 796 to 844. The row ends above it.
      expect(tester.getRect(last).bottom, lessThanOrEqualTo(796));
    },
  );

  testWidgets('the payment apps button waits for the list', (tester) async {
    final s = await testServices();
    final gate = Completer<List<Map<String, Object?>>>();
    final channel = MethodChannel(deviceChannelName);
    final messenger = tester.binding.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'installedApps') return gate.future;
      return null;
    });
    await pumpKoban(
      tester,
      s,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openPaymentApps(context),
            child: const Text('Open apps'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open apps'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Save without apps'), findsNothing);
    expect(find.text('Loading apps...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Loading apps...'),
          )
          .onPressed,
      isNull,
    );
    gate.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Loading apps...'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save without apps'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('the Activity month label has the primary color', (tester) async {
    await pumpHome(tester, await testServices());
    await tester.tap(find.byTooltip('Activity'));
    await settle(tester);
    final button = find.ancestor(
      of: find.byIcon(Icons.arrow_drop_down),
      matching: find.byType(TextButton),
    );
    final label = tester.widget<RichText>(
      find.descendant(of: button, matching: find.byType(RichText)).first,
    );
    expect(
      label.text.style!.color,
      kobanTheme(Brightness.light).colorScheme.primary,
    );
  });

  testWidgets('a snackbar does not cover the Add payment button', (
    tester,
  ) async {
    await pumpHome(tester, await testServices());
    final messenger = ScaffoldMessenger.of(
      tester.element(find.byType(KobanTabBar)),
    );
    showUndoSnackBar(messenger, 'Payment saved');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final fab = tester.getRect(find.byType(FloatingActionButton));
    // The SnackBar widget includes its margin. The Material is the bar itself.
    final bar = tester.getRect(
      find
          .descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(bar.overlaps(fab), isFalse, reason: 'snackbar $bar, button $fab');
    await tester.pump(const Duration(seconds: 6));
  });

  // Milestone 6: a failed start or a failed first load shows a text, not a blank screen.

  testWidgets('a failed start shows one line, not the splash', (tester) async {
    await tester.pumpWidget(
      await appRoot(() async => throw StateError('test-start-failure')),
    );
    expect(find.text(startFailedMessage), findsOneWidget);
  });

  testWidgets('Home says when its data cannot load', (tester) async {
    final s = await testServices();
    await s.db.customStatement('DROP TABLE expenses');
    await pumpHome(tester, s);
    expect(find.text(loadFailedMessage), findsOneWidget);
  });

  testWidgets('Activity says when its data cannot load', (tester) async {
    final s = await testServices();
    await s.db.customStatement('DROP TABLE expenses');
    await pumpActivity(tester, s);
    expect(inActivity(find.text(loadFailedMessage)), findsOneWidget);
  });

  testWidgets('Check payments says when its data cannot load', (tester) async {
    final s = await testServices();
    await s.db.customStatement('DROP TABLE pending_payments');
    await openCheck(tester, s);
    expect(find.text(loadFailedMessage), findsOneWidget);
    expect(find.text('All checked'), findsNothing);
  });

  testWidgets('an edited payment that cannot load shows the text and Back', (
    tester,
  ) async {
    final s = await testServices();
    final id = await addOne(s);
    await s.db.customStatement('DROP TABLE expenses');
    final opener = await openSheet(tester, s, expenseId: id);
    expect(find.text(loadFailedMessage), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(opener.closed, true);
  });

  testWidgets('Settings says when its categories cannot load', (tester) async {
    final s = await testServices();
    await s.db.customStatement('DROP TABLE categories');
    await pumpSettings(tester, s);
    expect(find.text(loadFailedMessage), findsOneWidget);
  });
}
