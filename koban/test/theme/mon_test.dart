import 'package:flutter_test/flutter_test.dart';
import 'package:koban/theme/mon.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Mon is 1.1 times as high as it is wide', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Mon(MonFace.happy, size: 120)),
    ));
    expect(tester.getSize(find.byType(Mon)), const Size(120, 132));
  });

  testWidgets('Mon has no label unless the screen gives one', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Mon(MonFace.idle, size: 60)),
    ));
    expect(find.bySemanticsLabel(RegExp('Mon')), findsNothing);
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
          child: Mon(MonFace.idle, size: 60, semanticLabel: 'Mon, sleeping')),
    ));
    expect(find.bySemanticsLabel(RegExp('Mon')), findsOneWidget);
  });
}
