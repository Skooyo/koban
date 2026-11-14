import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';

void main() {
  testWidgets('the People tab shows how many people have something open', (
    tester,
  ) async {
    final s = await testServices();
    final handle = tester.ensureSemantics();
    await tester.runAsync(() async {
      final ali = await s.people.addPerson('Ali');
      final mei = await s.people.addPerson('Mei');
      await s.people.addPerson('Dina');
      final t = s.now().millisecondsSinceEpoch;
      await s.people.addOwedToMe(ali, 'Cash', Decimal.parse('20'), t);
      await s.people.addOwedItem(mei, 'Teh', Decimal.parse('3'), t);
    });

    await pumpKoban(tester, s);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    final tab = find.ancestor(
      of: find.text('People'),
      matching: find.byType(NavigationDestination),
    );
    expect(find.descendant(of: tab, matching: find.text('2')), findsOneWidget);
    expect(tester.getSemantics(tab).label, '2 open\nPeople\nTab 3 of 4');
    handle.dispose();
  });
}
