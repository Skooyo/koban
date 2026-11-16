import 'package:material_ui/material_ui.dart';

import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../theme/koban_theme.dart';
import '../../ui/kit.dart';
import '../../ui/sheets.dart';

/// A sheet that lists Uncategorized and the [categories] by name. A tap on one
/// calls [onPick] (null for Uncategorized) and closes the sheet. With [mostUsedIds]
/// a "Most used" section (up to 4) comes first, and "All categories" lists the rest.
Future<void> showCategorySheet(
  BuildContext context, {
  required List<Category> categories,
  required String? selectedId,
  required ValueChanged<String?> onPick,
  List<String>? mostUsedIds,
}) {
  final byId = {for (final c in categories) c.id: c};
  final top = <Category>[
    for (final id in (mostUsedIds ?? const <String>[]).take(4)) ?byId[id],
  ];
  final rest = <(String?, String)>[
    (null, CategoryRepository.uncategorizedName),
    for (final c in categories)
      if (!top.contains(c)) (c.id, c.name),
  ];
  return showKobanSheet<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      Widget row(BuildContext context, String? id, String name) => Semantics(
        selected: id == selectedId,
        child: KobanRow(
          title: name,
          leading: CategoryDot(categoryColor(context, id), size: 12),
          trailing: id == selectedId
              ? Icon(
                  Icons.check,
                  semanticLabel: 'Selected',
                  color: theme.colorScheme.primary,
                )
              : null,
          onTap: () {
            onPick(id);
            Navigator.pop(context);
          },
        ),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Semantics(
              header: true,
              child: Text('Category', style: theme.textTheme.titleLarge),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  if (top.isNotEmpty) ...[
                    Text('Most used', style: theme.textTheme.titleSmall),
                    ListGroup(
                      children: [
                        for (final c in top) row(context, c.id, c.name),
                      ],
                    ),
                    Text('All categories', style: theme.textTheme.titleSmall),
                  ],
                  ListGroup(
                    children: [
                      for (final (id, name) in rest) row(context, id, name),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
