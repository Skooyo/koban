import 'package:material_ui/material_ui.dart';

import '../data/database.dart';
import '../theme/koban_theme.dart';
import 'kit.dart';

/// How many category chips a card or the payment page shows.
const categoryChipCount = 4;

/// The chips: the most used categories, then the rest by name.
/// The category [selectedId] takes the last chip when it is not in them.
List<Category> chipCategoriesFor(
  List<Category> categories,
  List<String> mostUsed,
  String? selectedId, {
  int count = categoryChipCount,
}) {
  final byId = {for (final c in categories) c.id: c};
  final chips = {
    for (final id in mostUsed) ?byId[id],
    ...categories,
  }.take(count).toList();
  final selected = byId[selectedId];
  if (selected != null && !chips.contains(selected)) {
    chips[chips.length - 1] = selected;
  }
  return chips;
}

/// The category chips, with More for the full list. A tap on a chip sets its category.
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.chips,
    required this.selectedId,
    required this.onPick,
    required this.onMore,
    this.flagNotSet = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Category> chips;
  final String? selectedId;
  final ValueChanged<String>? onPick;
  final VoidCallback? onMore;

  /// True: the label reads "Category · not set" in the review color when nothing is chosen.
  final bool flagNotSet;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notSet = flagNotSet && selectedId == null;
    final onPick = this.onPick;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            notSet ? 'Category · not set' : 'Category',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: notSet
                  ? MoneyColors.of(context).review
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in chips)
                ChoiceChip(
                  label: Text(c.name),
                  avatar: CategoryDot(categoryColor(context, c.id), size: 10),
                  showCheckmark: false,
                  selected: c.id == selectedId,
                  onSelected: onPick == null
                      ? null
                      : (_) {
                          if (c.id != selectedId) onPick(c.id);
                        },
                ),
              ActionChip(
                label: const Text('More…'),
                tooltip: 'All categories',
                onPressed: onMore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
