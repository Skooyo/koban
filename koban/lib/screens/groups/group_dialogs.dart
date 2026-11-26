import 'package:material_ui/material_ui.dart';

import '../../online/group_repository.dart';
import '../../ui/kit.dart';
import 'groups_view_model.dart';

/// Closes the dialog of [context] with [result]. A second tap during the close does nothing.
void _close<T>(BuildContext context, T result) {
  if (ModalRoute.of(context)?.isCurrent != true) return;
  Navigator.pop(context, result);
}

/// What [showTextDialog] gets back from its submit: [worked] closes the dialog,
/// an [error] shows under the field.
typedef TextSubmit = Future<({bool worked, String? error})> Function(
  String text,
);

/// Asks for a text of 1 to [max] characters and runs [submit] with it. The dialog
/// stays open until [submit] works; its error shows under the field. Gives true when it worked.
/// [transform] changes each typed value (for example to capitals). Without [helper],
/// the field shows a counter.
Future<bool> showTextDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String start,
  required String confirm,
  required int max,
  required TextSubmit submit,
  String? helper,
  String Function(String)? transform,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _TextDialog(
        title: title,
        label: label,
        start: start,
        confirm: confirm,
        max: max,
        submit: submit,
        helper: helper,
        transform: transform,
      ),
    ) ??
    false;

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.start,
    required this.confirm,
    required this.max,
    required this.submit,
    this.helper,
    this.transform,
  });

  final String title;
  final String label;
  final String start;
  final String confirm;
  final int max;
  final TextSubmit submit;
  final String? helper;
  final String Function(String)? transform;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late String _text = widget.start;
  String? _error;
  var _busy = false;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await widget.submit(_text.trim());
    if (!mounted) return;
    if (r.worked) {
      _close<bool>(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.max;
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      title: Text(widget.title),
      content: DialogTextField(
        value: _text,
        // As the 0.1.1 `take(max)`: UTF-16 code units.
        onChanged: (v) {
          final t = widget.transform?.call(v) ?? v;
          setState(() {
            _text = t.length > max ? t.substring(0, max) : t;
            _error = null;
          });
        },
        label: widget.label,
        isError: _error != null,
        supportingText:
            _error ?? widget.helper ?? '${_text.trim().length} of $max',
      ),
      actions: [
        TextButton(
          onPressed: () => _close<bool>(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _text.trim().isEmpty || _busy ? null : _submit,
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}

/// Asks before an action. Gives true for [confirm], false for Cancel.
/// [destructive] paints [confirm] red: use it only when the action deletes something.
/// A port of the 0.1.1 `ConfirmDialog`.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  bool destructive = false,
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
              style: destructive
                  ? TextButton.styleFrom(foregroundColor: scheme.error)
                  : null,
              child: Text(confirm),
            ),
          ],
        );
      },
    ) ??
    false;

/// Asks for a name and runs [action] with it. The dialog stays open until the
/// action works, and its error shows under the field. [onOk] runs after the dialog closes.
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
  String? helper,
  String Function(String)? transform,
}) async {
  final worked = await showTextDialog(
    context,
    title: title,
    label: label,
    start: start,
    confirm: confirm,
    max: max,
    helper: helper,
    transform: transform,
    submit: (text) async {
      var ok = false;
      String? error;
      await vm.run(
        (r) => action(r, text),
        onOk: () => ok = true,
        onError: (e) => error = e,
      );
      return (worked: ok, error: error);
    },
  );
  if (worked) onOk?.call();
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
  bool destructive = false,
}) async {
  while (true) {
    final ok = await showConfirmDialog(
      context,
      title: title,
      body: body,
      confirm: confirm,
      destructive: destructive,
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
