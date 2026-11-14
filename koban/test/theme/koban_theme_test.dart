import 'package:flutter_test/flutter_test.dart';
import 'package:koban/theme/koban_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('the dark theme uses the night, ink and gold tokens', () {
    final t = kobanTheme(Brightness.dark);
    expect(t.scaffoldBackgroundColor, const Color(0xFF141B2B));
    expect(t.colorScheme.primary, const Color(0xFFF2C94C));
    expect(t.colorScheme.onPrimary, const Color(0xFF2A2106));
    expect(t.colorScheme.surfaceContainer, const Color(0xFF1C2539));
    expect(t.colorScheme.onSurface, const Color(0xFFEDF0F7));
    expect(t.colorScheme.onSurfaceVariant, const Color(0xFFA2ACC2));
  });

  test('the light theme uses gold text as the primary color', () {
    final t = kobanTheme(Brightness.light);
    expect(t.colorScheme.primary, const Color(0xFF7A5D00));
    expect(t.colorScheme.onPrimary, const Color(0xFFFFFFFF));
    expect(t.scaffoldBackgroundColor, const Color(0xFFF6F7FA));
  });

  test('text styles follow the type tokens', () {
    final s = kobanTheme(Brightness.dark).textTheme;
    expect(s.displayLarge!.fontSize, 57);
    expect(s.displayLarge!.height, 64 / 57);
    expect(s.displayLarge!.letterSpacing, -1.5);
    expect(s.displayLarge!.fontFamily, 'Bricolage');
    expect(s.displayLarge!.fontVariations,
        [const FontVariation('wght', 700), const FontVariation('opsz', 96)]);
    expect(s.bodyMedium!.fontVariations,
        [const FontVariation('wght', 400), const FontVariation('opsz', 14)]);
  });

  testWidgets('category colors follow the category ids', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: kobanTheme(Brightness.dark),
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    expect(categoryColor(ctx, 'food'), const Color(0xFFFF6B5E));
    expect(categoryColor(ctx, null), const Color(0xFFA3AEBD));
    expect(categoryColor(ctx, 'c1'), const Color(0xFF8C9EFF));
  });

  testWidgets('light money colors follow the tokens', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: kobanTheme(Brightness.light),
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));
    expect(categoryColor(ctx, 'bills'), const Color(0xFFE07A0F));
    expect(MoneyColors.light.gold, const Color(0xFFF2C94C));
    expect(MoneyColors.light.goldText, const Color(0xFF7A5D00));
  });
}
