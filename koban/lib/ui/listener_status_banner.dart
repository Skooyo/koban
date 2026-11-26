import 'package:material_ui/material_ui.dart';

import '../theme/mon.dart';

/// A card with Mon and a "Turn on" button. Show it when tracking is off.
/// When tracking works, Mon's bubble on Home says so.
class ListenerStatusBanner extends StatelessWidget {
  const ListenerStatusBanner({super.key, required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Mon(MonFace.worry, size: 40),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tracking is off',
                    style: text.titleMedium!.copyWith(color: scheme.onSurface),
                  ),
                  Text(
                    'Koban cannot read notifications.',
                    style: text.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          TextButton(onPressed: onEnable, child: const Text('Turn on')),
        ],
      ),
    );
  }
}
