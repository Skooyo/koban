import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/theme/koban_theme.dart';
import 'package:koban/ui/dialogs.dart';
import 'package:koban/ui/kit.dart';
import 'package:koban/ui/listener_status_banner.dart';
import 'package:material_ui/material_ui.dart';

Widget app(Widget body) => MaterialApp(
  theme: kobanTheme(Brightness.light),
  home: Scaffold(body: body),
);

void main() {
  test('initials use the first letters of the first two words', () {
    expect(initialsOf("Touch 'n Go"), 'TN');
    expect(initialsOf('ali'), 'AL');
    expect(initialsOf('Ali Baba Sdn'), 'AB');
    expect(initialsOf('  '), '');
  });

  testWidgets('a row is at least 56 high and tells its tap action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      app(
        Center(
          child: KobanRow(
            title: 'Shop',
            onTap: () => taps++,
            onTapLabel: 'Change payment',
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(KobanRow)).height, 56);
    final node = tester.getSemantics(find.byType(KobanRow));
    expect(node.hintOverrides?.onTapHint, 'Change payment');
    expect(node.getSemanticsData().label, 'Shop');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.text('Shop'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a list group puts dividers between rows only', (tester) async {
    await tester.pumpWidget(
      app(
        ListGroup(
          children: [
            for (final t in ['A', 'B', 'C']) KobanRow(title: t),
          ],
        ),
      ),
    );
    expect(find.byType(Divider), findsNWidgets(2));
    await tester.pumpWidget(app(ListGroup(children: [KobanRow(title: 'A')])));
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('step progress says the step and its name', (tester) async {
    await tester.pumpWidget(
      app(const StepProgress(number: 2, total: 6, name: 'Items')),
    );
    expect(find.text('Step 2 of 6 · Items'), findsOneWidget);
  });

  testWidgets('the direction segments say Spent and Received and pick a type', (
    tester,
  ) async {
    TransactionType? picked;
    await tester.pumpWidget(
      app(
        DirectionSegments(
          selected: TransactionType.withdraw,
          onPick: (t) => picked = t,
        ),
      ),
    );
    expect(find.text('Spent'), findsOneWidget);
    await tester.tap(find.text('Received'));
    expect(picked, TransactionType.receive);
  });

  testWidgets('the discard dialog gives true only for Discard', (tester) async {
    bool? result;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showDiscardChangesDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    Future<void> open() async {
      result = null;
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Your changes are not saved.'), findsOneWidget);
    }

    await open();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await open();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await open();
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets(
    'the past date picker keeps the time of day and blocks tomorrow',
    (tester) async {
      final now = DateTime(2026, 11, 13, 12);
      final time = DateTime(2026, 11, 11, 20, 15).millisecondsSinceEpoch;
      int? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showPastDatePicker(
                context,
                time: time,
                now: now,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Tomorrow cannot be picked: OK keeps the first date.
      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, time);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 11, 12, 20, 15).millisecondsSinceEpoch);
    },
  );

  testWidgets('the status banner shows Turn on when tracking is off', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      app(ListenerStatusBanner(isAccessGranted: false, onEnable: () => taps++)),
    );
    expect(find.text('Tracking is off'), findsOneWidget);
    expect(find.text('Koban cannot read notifications.'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.text('Turn on'));
    expect(taps, 1);

    await tester.pumpWidget(
      app(ListenerStatusBanner(isAccessGranted: true, onEnable: () => taps++)),
    );
    expect(find.text('Tracking on'), findsOneWidget);
    expect(find.text('Turn on'), findsNothing);
  });
}
