import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';

/// The nearest slide of the page with [text]. The page below is offstage after a push.
SlideTransition slideOf(WidgetTester tester, String text) =>
    tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.text(text, skipOffstage: false),
            matching: find.byType(SlideTransition, skipOffstage: false),
          )
          .first,
    );

/// The nearest fade of the page with [text].
FadeTransition fadeOf(WidgetTester tester, String text) =>
    tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text(text, skipOffstage: false),
            matching: find.byType(FadeTransition, skipOffstage: false),
          )
          .first,
    );

BuildContext below(WidgetTester tester) =>
    tester.element(find.text('Below', skipOffstage: false));

double dx(WidgetTester tester) => tester.getTopLeft(find.text('Above')).dx;
double dy(WidgetTester tester) => tester.getTopLeft(find.text('Above')).dy;

void main() {
  testWidgets(
    'an opened page slides in and the page below moves 30% and darkens',
    (tester) async {
      await pumpKoban(tester, await testServices(), home: const Text('Below'));
      pushPage<void>(below(tester), const Text('Above'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 399));
      expect(dx(tester), greaterThan(0));
      await tester.pump(const Duration(milliseconds: 1));
      expect(dx(tester), 0);
      expect(slideOf(tester, 'Below').position.value, const Offset(-0.3, 0));
      expect(fadeOf(tester, 'Below').opacity.value, 0.6);
    },
  );

  testWidgets('Back slides the page out and brings the page below back', (
    tester,
  ) async {
    await pumpKoban(tester, await testServices(), home: const Text('Below'));
    pushPage<void>(below(tester), const Text('Above'));
    await tester.pumpAndSettle();
    Navigator.of(below(tester)).pop();
    await tester.pump();
    // 100 ms in: 800 * fastOutSlowIn(0.25) = 189.6, forward in time as in Compose.
    await tester.pump(const Duration(milliseconds: 100));
    expect(dx(tester), moreOrLessEquals(189.6, epsilon: 1.0));
    await tester.pump(const Duration(milliseconds: 299));
    expect(dx(tester), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 1));
    // At 400 ms the page is fully out (the test view is 800 wide).
    expect(dx(tester), 800);
    expect(slideOf(tester, 'Below').position.value, Offset.zero);
    expect(fadeOf(tester, 'Below').opacity.value, 1.0);
    // The controller ends after its last value, so the next tick removes the page.
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Above', skipOffstage: false), findsNothing);
  });

  testWidgets('the payment sheet rises in 450 ms and the page below stays', (
    tester,
  ) async {
    await pumpKoban(tester, await testServices(), home: const Text('Below'));
    pushSheet<void>(below(tester), const Text('Above'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 449));
    expect(dy(tester), greaterThan(0));
    expect(dx(tester), 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(dy(tester), 0);
    expect(slideOf(tester, 'Below').position.value, Offset.zero);
    expect(fadeOf(tester, 'Below').opacity.value, 1.0);
  });

  testWidgets('the sheet closes in 300 ms', (tester) async {
    await pumpKoban(tester, await testServices(), home: const Text('Below'));
    pushSheet<void>(below(tester), const Text('Above'));
    await tester.pumpAndSettle();
    Navigator.of(below(tester)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));
    expect(dy(tester), greaterThan(0));
    await tester.pump(const Duration(milliseconds: 1));
    // At 300 ms the sheet is fully down (the test view is 600 high).
    expect(dy(tester), 600);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Above', skipOffstage: false), findsNothing);
    expect(slideOf(tester, 'Below').position.value, Offset.zero);
    expect(fadeOf(tester, 'Below').opacity.value, 1.0);
  });

  // Review Focus 5.
  testWidgets('with animations off every page and sheet shows at once', (
    tester,
  ) async {
    await pumpKoban(
      tester,
      await testServices(),
      home: const Text('Below'),
      disableAnimations: true,
    );
    pushPage<void>(below(tester), const Text('Above'));
    await tester.pump();
    expect(dx(tester), 0);
    expect(slideOf(tester, 'Below').position.value, const Offset(-0.3, 0));
    expect(fadeOf(tester, 'Below').opacity.value, 0.6);
    Navigator.of(below(tester)).pop();
    await tester.pump();
    expect(find.text('Above', skipOffstage: false), findsNothing);
    expect(slideOf(tester, 'Below').position.value, Offset.zero);

    pushSheet<void>(below(tester), const Text('Above'));
    await tester.pump();
    expect(dy(tester), 0);
    Navigator.of(below(tester)).pop();
    await tester.pump();
    expect(find.text('Above', skipOffstage: false), findsNothing);
  });
}
