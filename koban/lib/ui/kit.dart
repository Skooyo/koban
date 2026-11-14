import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../rules/types.dart';
import '../theme/koban_theme.dart';

/// The style with another weight. The Bricolage font is a variable font, so the weight is an axis.
TextStyle weighted(TextStyle style, int weight) => style.copyWith(
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [
    FontVariation('wght', weight.toDouble()),
    ...?style.fontVariations?.where((v) => v.axis != 'wght'),
  ],
);

/// One rounded group of rows. A divider shows between rows only.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A list row with an optional subtitle, trailing content and chevron.
/// [leading] sits centered in a 40 dp box: pass a 24 dp icon or an avatar.
class KobanRow extends StatelessWidget {
  const KobanRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.leading,
    this.trailing,
    this.titleSuffix,
    this.showChevron = false,
    this.onTap,
    this.onTapLabel,
    this.subtitleMaxLines,
  });

  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? leading;
  final Widget? trailing;
  final Widget? titleSuffix;
  final bool showChevron;
  final VoidCallback? onTap;

  /// What a tap does, for screen readers.
  final String? onTapLabel;
  final int? subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = scheme.onSurfaceVariant;
    final titleText = Text(
      title,
      style: text.titleMedium!.copyWith(color: scheme.onSurface),
    );
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: IconTheme.merge(
                    data: IconThemeData(color: muted),
                    child: leading!,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titleSuffix == null)
                    titleText
                  else
                    Row(
                      children: [
                        Flexible(child: titleText),
                        const SizedBox(width: 8),
                        titleSuffix!,
                      ],
                    ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: text.bodyMedium!.copyWith(
                        color: subtitleColor ?? muted,
                      ),
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (showChevron)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.keyboard_arrow_right, color: muted, size: 24),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return MergeSemantics(child: body);
    return MergeSemantics(
      child: Semantics(
        button: true,
        onTapHint: onTapLabel,
        child: InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: theme.textTheme.titleSmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Money text with tabular figures. A big amount steps down the display sizes until it fits the width.
class MoneyText extends StatelessWidget {
  const MoneyText(this.text, {super.key, this.style, this.color});

  final String text;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    var base = style ?? t.titleMedium!;
    if (color != null) base = base.copyWith(color: color);
    final size = base.fontSize ?? 14;
    if (size <= 40) {
      return Text(text, style: tabular(base), maxLines: 1, softWrap: false);
    }
    final steps = [
      tabular(base),
      for (final s in [t.displayMedium!, t.displaySmall!, t.headlineLarge!])
        if ((s.fontSize ?? 0) < size) tabular(s.copyWith(color: base.color)),
    ];
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        bool fits(TextStyle s) {
          final p = TextPainter(
            text: TextSpan(text: text, style: s),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = p.width;
          p.dispose();
          return width <= constraints.maxWidth;
        }

        final fitted = steps.firstWhere(fits, orElse: () => steps.last);
        return Text(text, style: fitted, maxLines: 1, softWrap: false);
      },
    );
  }
}

class CategoryDot extends StatelessWidget {
  const CategoryDot(this.color, {super.key, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// The big left-aligned title of a top-level tab.
class LargeTopBar extends StatelessWidget {
  const LargeTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.headlineLarge!.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 4), a],
        ],
      ),
    );
  }
}

/// The second action: a primaryContainer fill. Use a filled button for the one gold action.
class TonalButton extends StatelessWidget {
  const TonalButton(this.text, this.onPressed, {super.key, this.icon});

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        minimumSize: const Size(0, 48),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Text(text, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

/// Spent and Received. A null [onPick] makes it a plain display.
/// A null [selected] means neither is chosen yet.
class DirectionSegments extends StatelessWidget {
  const DirectionSegments({
    super.key,
    this.selected,
    this.onPick,
    this.onTapWhenFixed,
  });

  final TransactionType? selected;
  final ValueChanged<TransactionType>? onPick;
  final VoidCallback? onTapWhenFixed;

  @override
  Widget build(BuildContext context) {
    const options = [
      ('Spent', TransactionType.withdraw),
      ('Received', TransactionType.receive),
    ];
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Segment(
              label: options[i].$1,
              on: selected == options[i].$2,
              onTap: onPick != null
                  ? () => onPick!(options[i].$2)
                  : onTapWhenFixed,
              onTapHint: onPick == null && onTapWhenFixed != null
                  ? 'Change payment'
                  : null,
            ),
          ),
        ],
      ],
    );
  }
}

/// Two or more choices in one track, for example Month | All. The chosen one is a gold-soft pill.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onPick,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _Segment(
                label: labels[i],
                on: i == selectedIndex,
                onTap: () => onPick(i),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.on,
    required this.onTap,
    this.onTapHint,
  });

  final String label;
  final bool on;
  final VoidCallback? onTap;
  final String? onTapHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: on,
      inMutuallyExclusiveGroup: true,
      button: onTap != null,
      onTapHint: onTapHint,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: Material(
        color: on ? scheme.primaryContainer : Colors.transparent,
        shape: StadiumBorder(
          side: on ? BorderSide(color: scheme.primary) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: Text(
                label,
                style: weighted(theme.textTheme.titleSmall!, 600).copyWith(
                  color: on
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A segmented progress bar (gold = done) with "Step [number] of [total] · [name]" under it.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.number,
    required this.total,
    required this.name,
  });

  final int number;
  final int total;
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  color: i < number
                      ? scheme.primary
                      : scheme.surfaceContainerHigh,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Step $number of $total · $name',
          style: theme.textTheme.labelLarge!.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Two letters of [name] in a circle. Screen readers skip it: the row title has the name.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.size = 40, this.tint});

  final String name;
  final double size;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = tint == null
        ? scheme.surfaceContainerHigh
        : tint!.withValues(alpha: tint == scheme.primaryContainer ? 1 : 0.3);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
        child: Text(
          initialsOf(name),
          style: Theme.of(context).textTheme.titleSmall!
              .copyWith(color: scheme.onSurface),
        ),
      ),
    );
  }
}

final _letterOrDigit = RegExp(r'[\p{L}\p{Nd}]', unicode: true);

/// The first letter of the first two words, or the first two letters of a one-word name.
/// Only letters and digits count, so "Touch 'n Go" gives "TN".
String initialsOf(String name) {
  final words = [
    for (final w in name.trim().split(RegExp(r'\s+')))
      _letterOrDigit.allMatches(w).map((m) => m.group(0)!).join(),
  ].where((w) => w.isNotEmpty).map((w) => w.characters.toList()).toList();
  final result = switch (words.length) {
    >= 2 => words[0].first + words[1].first,
    1 => words[0].take(2).join(),
    _ => name.trim().characters.take(1).toString(),
  };
  return result.toUpperCase();
}

/// A text field in the dialog style: filled `surfaceContainerHigh`, no underline.
class DialogTextField extends StatefulWidget {
  const DialogTextField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.isError = false,
    this.supportingText,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final bool isError;
  final String? supportingText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<DialogTextField> createState() => _DialogTextFieldState();
}

class _DialogTextFieldState extends State<DialogTextField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(DialogTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color? color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: color == null ? BorderSide.none : BorderSide(color: color),
    );
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.isError ? (widget.supportingText ?? '') : null,
        helperText: widget.isError ? null : widget.supportingText,
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: border(null),
        enabledBorder: border(null),
        focusedBorder: border(null),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error),
      ),
    );
  }
}
