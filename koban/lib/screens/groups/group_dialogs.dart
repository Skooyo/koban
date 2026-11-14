import 'package:material_ui/material_ui.dart';

import '../../online/group_repository.dart';
import '../../ui/kit.dart';
import 'groups_view_model.dart';

/// Closes the dialog of [context] with [result]. A second tap during the close does nothing.
void _close<T>(BuildContext context, T result) {
  if (ModalRoute.of(context)?.isCurrent != true) return;
  Navigator.pop(context, result);
}

/// Asks for a name of 1 to [max] characters. Gives the trimmed name, or null for Cancel.
/// A port of the 0.1.1 `NameDialog`.
Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String start,
  required String confirm,
  required int max,
}) => showDialog<String>(
  context: context,
  builder: (_) => _NameDialog(
    title: title,
    label: label,
    start: start,
    confirm: confirm,
    max: max,
  ),
);

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.label,
    required this.start,
    required this.confirm,
    required this.max,
  });

  final String title;
  final String label;
  final String start;
  final String confirm;
  final int max;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late String _text = widget.start;

  @override
  Widget build(BuildContext context) {
    final max = widget.max;
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      title: Text(widget.title),
      content: DialogTextField(
        value: _text,
        // As the 0.1.1 `take(max)`: UTF-16 code units.
        onChanged: (v) =>
            setState(() => _text = v.length > max ? v.substring(0, max) : v),
        label: widget.label,
        supportingText: '${_text.trim().length} of $max',
      ),
      actions: [
        TextButton(
          onPressed: () => _close<String?>(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _text.trim().isEmpty
              ? null
              : () => _close(context, _text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

/// Asks before an action. Gives true for [confirm], false for Cancel.
/// A port of the 0.1.1 `ConfirmDialog`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surfaceContainer,
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => _close(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => _close(context, true),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: Text(confirm),
            ),
          ],
        );
      },
    ) ??
    false;

/// Asks for a name and runs [action] with it. After a failed action the dialog
/// opens again with the typed text, as the 0.1.1 dialog stayed open until the action worked.
Future<void> askNameAndRun(
  BuildContext context,
  GroupsViewModel vm, {
  required String title,
  required String label,
  required String start,
  required String confirm,
  required int max,
  required Future<String?> Function(GroupRepository r, String text) action,
  VoidCallback? onOk,
}) async {
  var text = start;
  while (true) {
    final typed = await showNameDialog(
      context,
      title: title,
      label: label,
      start: text,
      confirm: confirm,
      max: max,
    );
    if (typed == null) return;
    text = typed;
    var worked = false;
    await vm.run(
      (r) => action(r, typed),
      onOk: () {
        worked = true;
        onOk?.call();
      },
    );
    if (worked ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
  }
}

/// Asks before [action] and runs it. After a failed action the question
/// opens again, as the 0.1.1 dialog stayed open until the action worked.
Future<void> askConfirmAndRun(
  BuildContext context,
  GroupsViewModel vm, {
  required String title,
  required String body,
  required String confirm,
  required Future<String?> Function(GroupRepository r) action,
  VoidCallback? onOk,
}) async {
  while (true) {
    final ok = await showConfirmDialog(
      context,
      title: title,
      body: body,
      confirm: confirm,
    );
    if (!ok) return;
    var worked = false;
    await vm.run(
      action,
      onOk: () {
        worked = true;
        onOk?.call();
      },
    );
    if (worked ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
  }
}
