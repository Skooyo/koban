import 'package:material_ui/material_ui.dart';

import '../../theme/tokens.dart';
import '../../ui/kit.dart';
import '../../ui/scene_band.dart';

/// The rounded icon tile at the start of a Settings row.
class RowIcon extends StatelessWidget {
  const RowIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(KobanRadius.r12),
      ),
      child: SizedBox.square(
        dimension: 40,
        child: Icon(icon, size: 22, color: scheme.onSurface),
      ),
    );
  }
}

/// A row with a switch. The whole row takes the tap. The switch only shows the state.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      toggled: value,
      child: KobanRow(
        title: title,
        subtitle: subtitle,
        leading: RowIcon(icon),
        trailing: ExcludeSemantics(
          child: IgnorePointer(
            child: Switch(value: value, onChanged: (_) {}),
          ),
        ),
        onTap: () => onChanged(!value),
      ),
    ),
  );
}

/// A Settings page: the task header and a list of content with the usual padding.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        TaskHeader(title: title),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    ),
  );
}
