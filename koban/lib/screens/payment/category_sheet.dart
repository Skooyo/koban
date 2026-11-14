import 'package:material_ui/material_ui.dart';

import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../theme/koban_theme.dart';
import '../../ui/kit.dart';

/// A sheet that lists Uncategorized and the [categories] by name. A tap on one
/// calls [onPick] (null for Uncategorized) and closes the sheet.
Future<void> showCategorySheet(
  BuildContext context, {
  required List<Category> categories,
  required String? selectedId,
  required ValueChanged<String?> onPick,
}) {
  final options = <(String?, String)>[
    (null, CategoryRepository.uncategorizedName),
    for (final c in categories) (c.id, c.name),
  ];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final theme = Theme.of(context);
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
              child: ListGroup(
                children: [
                  for (final (id, name) in options)
                    Semantics(
                      selected: id == selectedId,
                      child: KobanRow(
                        title: name,
                        leading: CategoryDot(
                          categoryColor(context, id),
                          size: 12,
                        ),
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
