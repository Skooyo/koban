import 'package:flutter_test/flutter_test.dart';
import 'package:koban/theme/tokens.dart';

void main() {
  test('dark and light palettes use the DESIGN.md values', () {
    expect(KobanColors.dark.night, 0xFF141B2B);
    expect(KobanColors.light.night, 0xFFF6F7FA);
    expect(KobanColors.dark.gold, 0xFFF2C94C);
    expect(KobanColors.light.goldText, 0xFF7A5D00);
    expect(KobanColors.dark.catOther, 0xFF8A96A8);
  });
  test('type scale uses the DESIGN.md values', () {
    expect(KobanType.displayLarge.size, 57);
    expect(KobanType.displayLarge.lineHeight, 64);
    expect(KobanType.displayLarge.weight, 700);
    expect(KobanType.labelSmall.size, 11);
  });
  test('spacing and radius use the DESIGN.md values', () {
    expect(KobanSpace.s16, 16);
    expect(KobanRadius.r24, 24);
    expect(KobanRadius.full, 999);
  });
}
