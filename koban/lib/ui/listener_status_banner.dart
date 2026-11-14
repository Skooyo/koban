import 'package:material_ui/material_ui.dart';

import '../theme/koban_theme.dart';
import '../theme/mon.dart';

/// A quiet one-line status when tracking works.
/// A card with Mon and a "Turn on" button when it does not.
class ListenerStatusBanner extends StatelessWidget {
  const ListenerStatusBanner({
    super.key,
    required this.isAccessGranted,
    required this.onEnable,
  });

  final bool isAccessGranted;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (isAccessGranted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MoneyColors.of(context).received,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Tracking on',
              style: text.labelLarge!.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
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
          TextButton(
            onPressed: onEnable,
            child: Text('Turn on', style: text.labelLarge),
          ),
        ],
      ),
    );
  }
}
