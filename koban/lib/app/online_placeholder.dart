import 'package:material_ui/material_ui.dart';

import '../ui/kit.dart';
import 'routes.dart';

/// The online parts that come in milestone 5. Milestone 5 deletes this file and each caller.
enum OnlineFeature {
  receiptReading('Receipt reading'),
  updates('Check for updates');

  const OnlineFeature(this.title);

  final String title;
}

/// A page for an online part that is not in the app yet. It never ships.
class OnlinePlaceholder extends StatelessWidget {
  const OnlinePlaceholder(this.feature, {super.key});

  final OnlineFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LargeTopBar(title: feature.title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Comes with the online features in milestone 5.',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens the placeholder of [feature] as a page with a Back button.
Future<void> openOnlinePlaceholder(
  BuildContext context,
  OnlineFeature feature,
) => pushPage<void>(
  context,
  Scaffold(appBar: AppBar(), body: OnlinePlaceholder(feature)),
);
