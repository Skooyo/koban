import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/home_shell.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';
import 'activity_screen_test.dart' show inActivity;
import 'check_payments_screen_test.dart' show Opener;

Finder _tab(String label) => find.ancestor(
  of: find.descendant(of: find.byType(KobanTabBar), matching: find.text(label)),
  matching: find.byType(InkResponse),
);

void main() {
  // A transaction that stays open queues every other query of the test database,
  // so the first load of a screen stays open until [release] completes.
  Completer<void> holdDatabase(dynamic s) {
    final release = Completer<void>();
    unawaited(s.db.transaction(() => release.future));
    return release;
  }

  testWidgets('Activity shows Loading, then the empty copy after the load', (
    tester,
  ) async {
    final s = await testServices();
    final release = holdDatabase(s);
    await pumpKoban(tester, s);
    await tester.tap(_tab('Activity'));
    await tester.pump();
    expect(inActivity(find.text('Loading')), findsOneWidget);
    expect(inActivity(find.textContaining('No payments')), findsNothing);
    release.complete();
    await tester.pumpAndSettle();
    expect(inActivity(find.text('Loading')), findsNothing);
    expect(
      inActivity(find.text('No payments in November 2026.')),
      findsOneWidget,
    );
  });

  testWidgets('Check payments shows Loading, then closes when no card waits', (
    tester,
  ) async {
    final s = await testServices();
    final release = holdDatabase(s);
    await pumpKoban(tester, s, home: const Opener());
    await tester.tap(find.text('Open check'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('Check payments'), findsOneWidget);
    release.complete();
    await tester.pumpAndSettle();
    expect(find.text('Loading'), findsNothing);
    expect(find.text('Check payments'), findsNothing);
  });
}
