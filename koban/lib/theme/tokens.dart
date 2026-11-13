/// Design tokens from docs/DESIGN.md. Pure Dart: no Flutter import.
/// Milestone 4 turns these into a Flutter ThemeData.
library;

/// One set of color tokens. Each value is a 0xFFrrggbb integer.
class KobanPalette {
  const KobanPalette({
    required this.night,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.ink,
    required this.muted,
    required this.gold,
    required this.onGold,
    required this.goldSoft,
    required this.goldText,
    required this.received,
    required this.error,
    required this.review,
    required this.catFood,
    required this.catTransport,
    required this.catShopping,
    required this.catBills,
    required this.catHealth,
    required this.catFun,
    required this.catCustom,
    required this.catOther,
    required this.coinRim,
    required this.coinShade,
    required this.coinShine,
  });

  final int night;
  final int surface;
  final int surface2;
  final int line;
  final int ink;
  final int muted;
  final int gold;
  final int onGold;
  final int goldSoft;
  final int goldText;
  final int received;
  final int error;
  final int review;
  final int catFood;
  final int catTransport;
  final int catShopping;
  final int catBills;
  final int catHealth;
  final int catFun;
  final int catCustom;
  final int catOther;
  final int coinRim;
  final int coinShade;
  final int coinShine;
}

class KobanColors {
  KobanColors._();

  static const dark = KobanPalette(
    night: 0xFF141B2B,
    surface: 0xFF1C2539,
    surface2: 0xFF243049,
    line: 0xFF2F3B57,
    ink: 0xFFEDF0F7,
    muted: 0xFFA2ACC2,
    gold: 0xFFF2C94C,
    onGold: 0xFF2A2106,
    goldSoft: 0xFF3A3420,
    goldText: 0xFFF2C94C,
    received: 0xFF6FD3A0,
    error: 0xFFFF7B6B,
    review: 0xFFF0B060,
    catFood: 0xFFFF6B5E,
    catTransport: 0xFF5B9BFF,
    catShopping: 0xFFA98BFF,
    catBills: 0xFFFFA94D,
    catHealth: 0xFF3CC6C0,
    catFun: 0xFFA8D45A,
    catCustom: 0xFF8C9EFF,
    catOther: 0xFF8A96A8,
    coinRim: 0xFFD9AE35,
    coinShade: 0xFFC99A22,
    coinShine: 0xFFFFF3C4,
  );

  static const light = KobanPalette(
    night: 0xFFF6F7FA,
    surface: 0xFFFFFFFF,
    surface2: 0xFFEEF1F6,
    line: 0xFFD9DEE8,
    ink: 0xFF161D2B,
    muted: 0xFF5A6478,
    gold: 0xFFF2C94C,
    onGold: 0xFF2A2106,
    goldSoft: 0xFFFBF1CF,
    goldText: 0xFF7A5D00,
    received: 0xFF16804A,
    error: 0xFFC8372A,
    review: 0xFFA85A00,
    catFood: 0xFFE5483B,
    catTransport: 0xFF1F6FE0,
    catShopping: 0xFF7B4FD6,
    catBills: 0xFFE07A0F,
    catHealth: 0xFF0E9C95,
    catFun: 0xFF6E9A12,
    catCustom: 0xFF4C5FD5,
    catOther: 0xFF6B7686,
    coinRim: 0xFFD9AE35,
    coinShade: 0xFFC99A22,
    coinShine: 0xFFFFF3C4,
  );
}

/// One text style. Size and line height are in sp, tracking is in px.
class KobanTextStyle {
  const KobanTextStyle(this.size, this.lineHeight, this.weight, this.tracking);

  final double size;
  final double lineHeight;
  final int weight;
  final double tracking;
}

class KobanType {
  KobanType._();

  static const displayLarge = KobanTextStyle(57, 64, 700, -1.5);
  static const displayMedium = KobanTextStyle(45, 52, 700, -1);
  static const displaySmall = KobanTextStyle(36, 44, 700, -0.5);
  static const headlineLarge = KobanTextStyle(32, 40, 600, -0.5);
  static const headlineMedium = KobanTextStyle(28, 36, 600, -0.25);
  static const headlineSmall = KobanTextStyle(24, 32, 600, 0);
  static const titleLarge = KobanTextStyle(22, 28, 600, 0);
  static const titleMedium = KobanTextStyle(16, 24, 600, 0);
  static const titleSmall = KobanTextStyle(14, 20, 600, 0);
  static const bodyLarge = KobanTextStyle(16, 24, 400, 0.5);
  static const bodyMedium = KobanTextStyle(14, 20, 400, 0.25);
  static const bodySmall = KobanTextStyle(12, 16, 400, 0.4);
  static const labelLarge = KobanTextStyle(14, 20, 500, 0.1);
  static const labelMedium = KobanTextStyle(12, 16, 500, 0.5);
  static const labelSmall = KobanTextStyle(11, 16, 500, 0.5);
}

class KobanSpace {
  KobanSpace._();

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
}

class KobanRadius {
  KobanRadius._();

  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r24 = 24;
  static const double full = 999;
}
