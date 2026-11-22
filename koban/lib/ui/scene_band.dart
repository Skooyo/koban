import 'package:material_ui/material_ui.dart';

import '../theme/koban_theme.dart';
import '../theme/mon.dart';
import '../theme/tokens.dart';

/// The teal band at the top of a screen: a title row, Mon, and Mon's speech bubble.
///
/// Put it first in the screen's scroll view or column, with no gap after it. The band's
/// ground paints [overlap] px below the band, under the next widget, so the first card
/// overlaps the band as in the Mon's desk look. Give that content 16 px side padding.
///
/// The band pads itself for the status bar from [MediaQuery.paddingOf], so do not put
/// it in a top [SafeArea]. Screen readers read the title as a header and the bubble as
/// one text. Mon is decoration.
class SceneBand extends StatelessWidget {
  const SceneBand({
    super.key,
    required this.title,
    required this.face,
    required this.line,
    this.detail,
    this.stats = const [],
    this.back = false,
    this.action,
    this.onCoins = true,
    this.compact = false,
  });

  /// How far the ground paints below the band, under the content that follows it.
  static const overlap = 24.0;

  final String title;
  final MonFace face;

  /// The first, strong sentence of the bubble.
  final String line;

  /// The second, quieter sentence of the bubble.
  final String? detail;

  /// Short facts in small pills under the bubble, such as '0 to check'.
  final List<String> stats;

  /// True shows a back button before the title. It pops as the system Back does.
  final bool back;

  /// The widget at the end of the title row. Use a [SceneIconButton] for an icon.
  final Widget? action;

  /// True puts Mon on a pile of coins.
  final bool onCoins;

  /// True is the low band of a pushed screen or a busy tab: a small Mon at the right.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scene = SceneColors.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final groundHeight = compact ? 48.0 : 72.0;

    final titleRow = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          if (back) ...[
            SceneIconButton(
              icon: Icons.arrow_back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.maybePop(context),
            ),
            const SizedBox(width: KobanSpace.s8),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: (back ? text.titleLarge : text.headlineSmall)!.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: KobanSpace.s12),
            action!,
          ],
        ],
      ),
    );

    const tail = Radius.circular(4);
    const round = Radius.circular(18);
    final bubble = MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.only(
            topLeft: round,
            topRight: round,
            bottomLeft: compact ? round : tail,
            bottomRight: compact ? tail : round,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              line,
              style: text.titleSmall!.copyWith(color: scheme.onSurface),
            ),
            if (detail != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  detail!,
                  style: text.bodyMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final talk = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        if (stats.isNotEmpty) ...[
          const SizedBox(height: KobanSpace.s8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final s in stats) _StatPill(s)],
          ),
        ],
      ],
    );

    final mon = _MonOnPile(
      face: face,
      size: compact ? 56 : 104,
      coins: onCoins ? (compact ? 1 : 2) : 0,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: -overlap,
          child: ColoredBox(color: scene.band),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: -overlap,
          height: groundHeight,
          child: ColoredBox(color: scene.ground),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + KobanSpace.s16,
            20,
            compact ? 8 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              titleRow,
              const SizedBox(height: KobanSpace.s12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: compact
                    ? [
                        Expanded(child: talk),
                        const SizedBox(width: KobanSpace.s16),
                        mon,
                      ]
                    : [
                        mon,
                        const SizedBox(width: KobanSpace.s16),
                        Expanded(child: talk),
                      ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A round icon button for the title row of a [SceneBand], such as Settings.
/// The target is 48 dp. [tooltip] is the screen reader label too.
class SceneIconButton extends StatelessWidget {
  const SceneIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainer.withValues(alpha: 0.7),
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 48),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainer,
        shape: const StadiumBorder(),
      ),
      child: Text(
        text,
        style: tabular(
          theme.textTheme.labelMedium!.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Mon standing on [coins] flat coins. Zero coins is Mon alone.
class _MonOnPile extends StatelessWidget {
  const _MonOnPile({
    required this.face,
    required this.size,
    required this.coins,
  });

  final MonFace face;
  final double size;
  final int coins;

  @override
  Widget build(BuildContext context) {
    final mon = Mon(face, size: size);
    if (coins == 0) return mon;
    final pile = _CoinPile(coins, size * 1.15);
    return SizedBox(
      width: pile.width,
      height: pile.monBottom + size * 1.1,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned.fill(child: CustomPaint(painter: _CoinPilePainter(pile))),
          Positioned(bottom: pile.monBottom, child: mon),
        ],
      ),
    );
  }
}

/// The geometry of a pile of flat coins, from the bottom coin up. Each coin above is
/// narrower and sits [rise] higher.
class _CoinPile {
  _CoinPile(this.count, this.width);

  final int count;
  final double width;

  double get height => width * 0.25;
  double get rise => width * 0.2;
  double get shadow => width * 0.05;

  double widthOf(int i) => width * (1 - 0.14 * i);
  double heightOf(int i) => height * (1 - 0.14 * i);

  /// The bottom of coin [i], up from the pile bottom.
  double bottomOf(int i) => shadow + rise * i;

  /// Mon stands with its foot at the middle of the top coin.
  double get monBottom => bottomOf(count - 1) + heightOf(count - 1) / 2;
}

class _CoinPilePainter extends CustomPainter {
  _CoinPilePainter(this.pile);

  final _CoinPile pile;

  static final _gold = Color(KobanColors.light.gold);
  static final _rim = Color(KobanColors.light.coinRim);
  static final _shade = Color(KobanColors.light.coinShade);

  @override
  void paint(Canvas canvas, Size size) {
    final rim = Paint()
      ..color = _rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < pile.count; i++) {
      final h = pile.heightOf(i);
      final coin = Rect.fromCenter(
        center: Offset(size.width / 2, size.height - pile.bottomOf(i) - h / 2),
        width: pile.widthOf(i),
        height: h,
      );
      canvas.drawOval(
        coin.shift(Offset(0, pile.shadow)),
        Paint()..color = _shade,
      );
      canvas.drawOval(coin, Paint()..color = _gold);
      canvas.drawOval(coin.deflate(1), rim);
    }
  }

  @override
  bool shouldRepaint(_CoinPilePainter old) =>
      old.pile.count != pile.count || old.pile.width != pile.width;
}
