import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/groups/groups_screen.dart';
import 'package:koban/screens/home/home_screen.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/ui/scene_band.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';

/// A line of the Groups tab when signed out.
const groupsLine = 'Compare spending with friends';

int shownTab(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;

void main() {
  testWidgets(
    'the tab bar has Home, Activity, People and Groups with Home on',
    (tester) async {
      await pumpKoban(tester, await testServices());
      final bar = find.byType(KobanTabBar);
      expect(
        [
          for (final icon in tester.widgetList<Icon>(
            find.descendant(of: bar, matching: find.byType(Icon)),
          ))
            icon.icon,
        ],
        [Icons.home, Icons.receipt_long, Icons.people, Icons.groups],
      );
      // The shown tab has its label. The others have the label as tooltip only.
      expect(
        find.descendant(of: bar, matching: find.text('Home')),
        findsOneWidget,
      );
      for (final label in ['Activity', 'People', 'Groups']) {
        expect(find.byTooltip(label), findsOneWidget);
        expect(
          find.descendant(of: bar, matching: find.text(label)),
          findsNothing,
        );
      }
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byTooltip('Activity')),
        matchesSemantics(
          label: 'Activity\nTab 2 of 4',
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Home\nTab 1 of 4')),
        matchesSemantics(
          label: 'Home\nTab 1 of 4',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      expect(shownTab(tester), 0);
      expect(
        tester.state<HomeShellState>(find.byType(HomeShell)).tab,
        KobanTab.home,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  testWidgets(
    'a tab switch shows the new tab in the same frame and keeps the old tab',
    (tester) async {
      final s = await testServices();
      for (var i = 0; i < 12; i++) {
        await s.expenses.addManualExpense(
          amount: Decimal.parse('${i + 1}.00'),
          merchant: 'Kedai Contoh',
          postTime: DateTime(2026, 11, 13, 9).millisecondsSinceEpoch,
          categoryId: 'food',
          notes: null,
          type: TransactionType.withdraw,
        );
      }
      await pumpKoban(tester, s);
      await tester.pumpAndSettle();
      // Home keeps its scroll offset over a tab switch.
      final home = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(home).position.jumpTo(200);
      await tester.pump();
      expect(tester.state<ScrollableState>(home).position.pixels, 200);

      await tester.tap(find.byTooltip('Groups'));
      await tester.pump();
      expect(shownTab(tester), 3);
      expect(find.text(groupsLine), findsOneWidget);
      final groups = tester.element(find.byType(GroupsScreen));

      await tester.tap(find.byTooltip('Activity'));
      await tester.pump();
      expect(shownTab(tester), 1);
      expect(
        find.descendant(
          of: find.byType(KobanTabBar),
          matching: find.text('Activity'),
        ),
        findsOneWidget,
      );
      // The real Activity tab shows in the same frame, with no settle.
      expect(
        find.descendant(
          of: find.byType(SceneBand),
          matching: find.text('Activity'),
        ),
        findsOneWidget,
      );
      // The Groups tab stays in the tree, hidden, with the same element.
      expect(find.text(groupsLine), findsNothing);
      expect(
        tester.element(find.byType(GroupsScreen, skipOffstage: false)),
        same(groups),
      );

      HomeShell.of(tester.element(find.byType(IndexedStack)))
          .select(KobanTab.groups);
      await tester.pump();
      expect(shownTab(tester), 3);
      expect(tester.element(find.byType(GroupsScreen)), same(groups));

      await tester.tap(find.byTooltip('Home'));
      await tester.pump();
      expect(shownTab(tester), 0);
      expect(tester.state<ScrollableState>(home).position.pixels, 200);
    },
  );

  testWidgets('Back on another tab shows Home and Back on Home may close', (
    tester,
  ) async {
    await pumpKoban(tester, await testServices());
    await tester.tap(find.byTooltip('Activity'));
    await tester.pump();
    expect(shownTab(tester), 1);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(shownTab(tester), 0);
    expect(find.byType(HomeShell), findsOneWidget);
    // On Home the shell lets Back close the app.
    expect(
      find.byWidgetPredicate((w) => w is PopScope && w.canPop),
      findsOneWidget,
    );
  });

  testWidgets('the Groups tab shows the online placeholder', (tester) async {
    await pumpKoban(tester, await testServices(), textScale: 1.3);
    await tester.tap(find.byTooltip('Groups'));
    await tester.pump();
    // 'Groups' is the tab label and the placeholder title.
    expect(find.text('Groups'), findsNWidgets(2));
    expect(find.text(groupsLine), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app follows the dark mode setting', (tester) async {
    final s = await testServices(prefs: {'dark_mode': false});
    await pumpKoban(tester, s);
    Brightness brightness() =>
        Theme.of(tester.element(find.byType(HomeShell))).brightness;
    expect(brightness(), Brightness.light);

    await s.settings.setDarkMode(true);
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
  });
}
