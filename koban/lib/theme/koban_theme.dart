import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// The money colors of 0.1.1 (`Theme.kt` `MoneyColors`).
@immutable
class MoneyColors extends ThemeExtension<MoneyColors> {
  const MoneyColors({
    required this.received,
    required this.review,
    required this.red,
    required this.blue,
    required this.orange,
    required this.purple,
    required this.teal,
    required this.green,
    required this.gold,
    required this.goldText,
    required this.custom,
    required this.other,
    required this.uncategorized,
  });

  final Color received;
  final Color review;
  final Color red;
  final Color blue;
  final Color orange;
  final Color purple;
  final Color teal;
  final Color green;
  final Color gold;
  final Color goldText;
  final Color custom;
  final Color other;
  final Color uncategorized;

  static final light = MoneyColors(
    received: Color(0xFF16804A),
    review: Color(0xFFA85A00),
    red: Color(0xFFE5483B),
    blue: Color(0xFF1F6FE0),
    orange: Color(KobanColors.light.catBills),
    purple: Color(0xFF7B4FD6),
    teal: Color(0xFF0E9C95),
    green: Color(0xFF6E9A12),
    gold: Color(KobanColors.light.gold),
    goldText: Color(KobanColors.light.goldText),
    custom: Color(0xFF4C5FD5),
    other: Color(0xFF6B7686),
    uncategorized: Color(0xFF6B7686),
  );

  static const dark = MoneyColors(
    received: Color(0xFF6FD3A0),
    review: Color(0xFFF0B060),
    red: Color(0xFFFF6B5E),
    blue: Color(0xFF5B9BFF),
    orange: Color(0xFFFFA94D),
    purple: Color(0xFFA98BFF),
    teal: Color(0xFF3CC6C0),
    green: Color(0xFFA8D45A),
    gold: Color(0xFFF2C94C),
    goldText: Color(0xFFF2C94C),
    custom: Color(0xFF8C9EFF),
    other: Color(0xFF8A96A8),
    uncategorized: Color(0xFFA3AEBD),
  );

  static MoneyColors of(BuildContext context) =>
      Theme.of(context).extension<MoneyColors>()!;

  @override
  MoneyColors copyWith({
    Color? received,
    Color? review,
    Color? red,
    Color? blue,
    Color? orange,
    Color? purple,
    Color? teal,
    Color? green,
    Color? gold,
    Color? goldText,
    Color? custom,
    Color? other,
    Color? uncategorized,
  }) => MoneyColors(
    received: received ?? this.received,
    review: review ?? this.review,
    red: red ?? this.red,
    blue: blue ?? this.blue,
    orange: orange ?? this.orange,
    purple: purple ?? this.purple,
    teal: teal ?? this.teal,
    green: green ?? this.green,
    gold: gold ?? this.gold,
    goldText: goldText ?? this.goldText,
    custom: custom ?? this.custom,
    other: other ?? this.other,
    uncategorized: uncategorized ?? this.uncategorized,
  );

  @override
  MoneyColors lerp(MoneyColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MoneyColors(
      received: l(received, other.received),
      review: l(review, other.review),
      red: l(red, other.red),
      blue: l(blue, other.blue),
      orange: l(orange, other.orange),
      purple: l(purple, other.purple),
      teal: l(teal, other.teal),
      green: l(green, other.green),
      gold: l(gold, other.gold),
      goldText: l(goldText, other.goldText),
      custom: l(custom, other.custom),
      other: l(this.other, other.other),
      uncategorized: l(uncategorized, other.uncategorized),
    );
  }
}

/// The colors of the Mon's desk look: the scene band and the pill tab bar.
@immutable
class SceneColors extends ThemeExtension<SceneColors> {
  const SceneColors({
    required this.band,
    required this.ground,
    required this.tabBar,
    required this.onTabBar,
  });

  SceneColors.fromPalette(KobanPalette p)
    : band = Color(p.sceneBand),
      ground = Color(p.sceneGround),
      tabBar = Color(p.tabBar),
      onTabBar = Color(p.onTabBar);

  /// The band behind the title, Mon and the speech bubble. Text on it uses onSurface.
  final Color band;

  /// The strip at the foot of the band that Mon and the coins stand on.
  final Color ground;
  final Color tabBar;

  /// The icons of the inactive tabs.
  final Color onTabBar;

  static SceneColors of(BuildContext context) =>
      Theme.of(context).extension<SceneColors>()!;

  @override
  SceneColors copyWith({
    Color? band,
    Color? ground,
    Color? tabBar,
    Color? onTabBar,
  }) => SceneColors(
    band: band ?? this.band,
    ground: ground ?? this.ground,
    tabBar: tabBar ?? this.tabBar,
    onTabBar: onTabBar ?? this.onTabBar,
  );

  @override
  SceneColors lerp(SceneColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SceneColors(
      band: l(band, other.band),
      ground: l(ground, other.ground),
      tabBar: l(tabBar, other.tabBar),
      onTabBar: l(onTabBar, other.onTabBar),
    );
  }
}

/// The glyph of a category id. All custom categories share one glyph, as they share one color.
IconData categoryIcon(String? categoryId) => switch (categoryId) {
  'food' => Icons.restaurant,
  'transport' => Icons.directions_car,
  'shopping' => Icons.shopping_bag,
  'bills' => Icons.bolt,
  'entertainment' => Icons.movie,
  'health' => Icons.favorite,
  'other' => Icons.more_horiz,
  null => Icons.help_outline,
  _ => Icons.label,
};

/// The color of a category id. All custom categories share one color.
Color categoryColor(BuildContext context, String? categoryId) {
  final c = MoneyColors.of(context);
  return switch (categoryId) {
    'food' => c.red,
    'transport' => c.blue,
    'shopping' => c.purple,
    'bills' => c.orange,
    'entertainment' => c.green,
    'health' => c.teal,
    'other' => c.other,
    null => c.uncategorized,
    _ => c.custom,
  };
}

/// Returns the style with tabular figures, for amounts.
TextStyle tabular(TextStyle style) => style.copyWith(
  fontFeatures: [...?style.fontFeatures, const FontFeature.tabularFigures()],
);

// Light and dark schemes: `Theme.kt` LightColors and DarkColors.
const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF7A5D00),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFBF1CF),
  onPrimaryContainer: Color(0xFF7A5D00),
  secondary: Color(0xFF4A5A70),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDDE3EA),
  onSecondaryContainer: Color(0xFF1B2430),
  tertiary: Color(0xFFA85A00),
  onTertiary: Color(0xFFFFFFFF),
  error: Color(0xFFC8372A),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFFF6F7FA),
  onSurface: Color(0xFF161D2B),
  onSurfaceVariant: Color(0xFF5A6478),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFFFFFF),
  surfaceContainer: Color(0xFFFFFFFF),
  surfaceContainerHigh: Color(0xFFEEF1F6),
  surfaceContainerHighest: Color(0xFFE6EAF1),
  outline: Color(0xFF8C97A5),
  outlineVariant: Color(0xFFD9DEE8),
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFF2C94C),
  onPrimary: Color(0xFF2A2106),
  primaryContainer: Color(0xFF3A3420),
  onPrimaryContainer: Color(0xFFF2C94C),
  secondary: Color(0xFFB4C0D0),
  onSecondary: Color(0xFF1E2938),
  secondaryContainer: Color(0xFF33415A),
  onSecondaryContainer: Color(0xFFE3EAF5),
  tertiary: Color(0xFFF0B060),
  error: Color(0xFFFF7B6B),
  onError: Color(0xFF5C0E14),
  errorContainer: Color(0xFF7A1F2B),
  onErrorContainer: Color(0xFFFFE3E0),
  surface: Color(0xFF141B2B),
  onSurface: Color(0xFFEDF0F7),
  onSurfaceVariant: Color(0xFFA2ACC2),
  surfaceContainerLowest: Color(0xFF10172A),
  surfaceContainerLow: Color(0xFF18203A),
  surfaceContainer: Color(0xFF1C2539),
  surfaceContainerHigh: Color(0xFF243049),
  surfaceContainerHighest: Color(0xFF2B3957),
  outline: Color(0xFF6B7788),
  outlineVariant: Color(0xFF2F3B57),
);

/// The font look of the 0.1.1 release build. On the phone, 0.1.1 draws every text at the
/// font's default instance (weight 800, optical size 96), and the owner keeps that look.
/// The token weights and optical sizes stay for size, line height and tracking only.
const kobanFontVariations = [
  FontVariation('wght', 800),
  FontVariation('opsz', 96),
];

TextStyle _style(KobanTextStyle t, double opticalSize) => TextStyle(
  fontFamily: 'Bricolage',
  fontSize: t.size,
  height: t.lineHeight / t.size,
  letterSpacing: t.tracking,
  fontWeight: FontWeight.w800,
  fontVariations: kobanFontVariations,
);

/// The Koban theme. It is the 0.1.1 theme with the colors of DESIGN.md.
ThemeData kobanTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark ? _darkScheme : _lightScheme;
  final p = dark ? KobanColors.dark : KobanColors.light;
  final night = Color(p.night);
  final ink = Color(p.ink);
  final textTheme = TextTheme(
    displayLarge: _style(KobanType.displayLarge, 96),
    displayMedium: _style(KobanType.displayMedium, 96),
    displaySmall: _style(KobanType.displaySmall, 96),
    headlineLarge: _style(KobanType.headlineLarge, 96),
    headlineMedium: _style(KobanType.headlineMedium, 96),
    headlineSmall: _style(KobanType.headlineSmall, 96),
    titleLarge: _style(KobanType.titleLarge, 14),
    titleMedium: _style(KobanType.titleMedium, 14),
    titleSmall: _style(KobanType.titleSmall, 14),
    bodyLarge: _style(KobanType.bodyLarge, 14),
    bodyMedium: _style(KobanType.bodyMedium, 14),
    bodySmall: _style(KobanType.bodySmall, 14),
    labelLarge: _style(KobanType.labelLarge, 14),
    labelMedium: _style(KobanType.labelMedium, 14),
    labelSmall: _style(KobanType.labelSmall, 14),
  );
  const stadium = StadiumBorder();
  const minHeight = WidgetStatePropertyAll(Size(0, 48));
  const buttonStyle = ButtonStyle(
    shape: WidgetStatePropertyAll(stadium),
    minimumSize: minHeight,
  );
  // The one gold action of a page is gold in both themes, as in the Mon's desk look.
  final gold = Color(p.gold);
  final onGold = Color(p.onGold);
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(KobanRadius.r24),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: night,
    textTheme: textTheme,
    extensions: [
      dark ? MoneyColors.dark : MoneyColors.light,
      SceneColors.fromPalette(p),
    ],
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: cardShape,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: gold,
      foregroundColor: onGold,
      shape: const StadiumBorder(),
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: ink,
      contentTextStyle: textTheme.bodyMedium!.copyWith(color: night),
      actionTextColor: Color(
        dark ? KobanColors.light.goldText : KobanColors.dark.gold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KobanRadius.r12),
      ),
      behavior: SnackBarBehavior.floating,
      // The tab pages put the "Add ..." button 16 up from the tab bar. It is 56 high,
      // so the snackbar floats 16 above it and never covers it.
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KobanRadius.r24),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KobanRadius.r24),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: onGold,
      ).merge(buttonStyle),
    ),
    outlinedButtonTheme: const OutlinedButtonThemeData(style: buttonStyle),
    textButtonTheme: const TextButtonThemeData(style: buttonStyle),
  );
}
