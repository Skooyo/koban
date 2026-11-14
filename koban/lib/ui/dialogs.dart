import 'package:material_ui/material_ui.dart';

/// Ask before typed changes are dropped. Return true for Discard.
/// A tap outside the dialog means keep editing.
Future<bool> showDiscardChangesDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final text = Theme.of(context).textTheme;
      return AlertDialog(
        backgroundColor: scheme.surfaceContainer,
        title: Text('Discard changes?', style: text.headlineSmall),
        content: Text('Your changes are not saved.', style: text.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: const Text('Discard'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// [time] moved to the date [day], keeping the local time of day of [time].
int withDate(int time, DateTime day) {
  final t = DateTime.fromMillisecondsSinceEpoch(time);
  return DateTime(
    day.year,
    day.month,
    day.day,
    t.hour,
    t.minute,
    t.second,
    t.millisecond,
  ).millisecondsSinceEpoch;
}

/// A date picker up to today. Return [time] moved to the picked date, or null if the owner cancels.
Future<int?> showPastDatePicker(
  BuildContext context, {
  required int time,
  required DateTime now,
}) async {
  final today = DateTime(now.year, now.month, now.day);
  final t = DateTime.fromMillisecondsSinceEpoch(time);
  final initial = DateTime(t.year, t.month, t.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: initial.isAfter(today) ? today : initial,
    firstDate: DateTime(1900),
    lastDate: today,
    confirmText: 'OK',
    cancelText: 'Cancel',
  );
  return picked == null ? null : withDate(time, picked);
}
