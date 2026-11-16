import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/koban_app.dart';
import 'package:koban/app/routes.dart';
import 'package:koban/screens/payment/category_sheet.dart';
import 'package:koban/theme/koban_theme.dart';
import 'package:koban/ui/undo_snack_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';
import 'home_screen_test.dart' show pumpHome;
import 'person_screen_test.dart' show settle;

void main() {
  testWidgets('the system bars follow the theme and the app sets them', (
    tester,
  ) async {
    final dark = systemBarStyle(kobanTheme(Brightness.dark));
    expect(dark.systemNavigationBarColor, const Color(0xFF1C2539));
    expect(dark.systemNavigationBarIconBrightness, Brightness.light);
    expect(dark.statusBarIconBrightness, Brightness.light);
    final light = systemBarStyle(kobanTheme(Brightness.light));
    expect(light.systemNavigationBarColor, const Color(0xFFFFFFFF));
    expect(light.systemNavigationBarIconBrightness, Brightness.dark);
    expect(light.statusBarIconBrightness, Brightness.dark);

    await pumpHome(tester, await testServices());
    final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
    );
    expect(
      regions.map((r) => r.value.systemNavigationBarColor),
      contains(const Color(0xFF1C2539)),
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
    await tester.tap(find.text('Activity'));
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
      kobanTheme(Brightness.dark).colorScheme.primary,
    );
  });

  testWidgets('a snackbar does not cover the Add payment button', (
    tester,
  ) async {
    await pumpHome(tester, await testServices());
    final messenger = ScaffoldMessenger.of(
      tester.element(find.byType(NavigationBar)),
    );
    showUndoSnackBar(messenger, 'Expense added');
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
}
