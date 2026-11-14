import 'package:material_ui/material_ui.dart';

import 'release_parser.dart';
import 'update_repository.dart';

/// The size in MB that the dialog shows: at least 1, rounded as in 0.1.1.
int updateSizeMb(AvailableUpdate update) =>
    (update.apkSize / 1000000).round().clamp(1, 1 << 30);

/// True for the 4 states that show a dialog.
bool _isDialogState(UpdateState s) =>
    s is UpdateAvailable ||
    s is UpdateDownloading ||
    s is UpdateInstalling ||
    s is UpdateFailed;

/// The 4 dialogs of `UpdateDialog.kt`. Idle and up to date show nothing.
class UpdateDialogContent extends StatelessWidget {
  const UpdateDialogContent({
    super.key,
    required this.state,
    required this.onUpdate,
    required this.onDismiss,
  });

  final UpdateState state;
  final VoidCallback onUpdate;
  final VoidCallback onDismiss;

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = scheme.surfaceContainer;
    return switch (state) {
      UpdateAvailable(:final update) => AlertDialog(
        backgroundColor: color,
        shape: _shape,
        title: Text('Update available', style: text.headlineSmall),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Koban ${update.versionName} is ready (${updateSizeMb(update)} MB).',
                style: text.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (update.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  update.notes,
                  style: text.bodyMedium!.copyWith(color: scheme.onSurface),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: onDismiss, child: const Text('Later')),
          TextButton(onPressed: onUpdate, child: const Text('Update')),
        ],
      ),
      UpdateDownloading() => AlertDialog(
        backgroundColor: color,
        shape: _shape,
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Downloading the update…'),
            SizedBox(height: 16),
            LinearProgressIndicator(),
          ],
        ),
      ),
      UpdateInstalling() => AlertDialog(
        backgroundColor: color,
        shape: _shape,
        content: const Text('Installing…'),
        actions: [TextButton(onPressed: onDismiss, child: const Text('Close'))],
      ),
      UpdateFailed(:final message) => AlertDialog(
        backgroundColor: color,
        shape: _shape,
        content: Text(message),
        actions: [TextButton(onPressed: onDismiss, child: const Text('OK'))],
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Opens one dialog when [updates] gets a dialog state, over any page.
/// Later, Close, OK, Back and a tap outside call `later()`. Downloading has no dismiss.
/// The dialog closes itself on idle and on up to date.
/// Returns the function that stops the watch.
VoidCallback watchUpdateDialog(BuildContext context, UpdateRepository updates) {
  var open = false;
  BuildContext? dialogContext;

  void onState() {
    final s = updates.state.value;
    if (open) {
      if (!_isDialogState(s) && dialogContext?.mounted == true) {
        Navigator.of(dialogContext!).pop();
      }
      return;
    }
    if (!_isDialogState(s) || !context.mounted) return;
    open = true;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        dialogContext = ctx;
        return ValueListenableBuilder<UpdateState>(
          valueListenable: updates.state,
          builder: (ctx, state, _) => PopScope(
            canPop: state is! UpdateDownloading,
            child: UpdateDialogContent(
              state: state,
              onUpdate: updates.downloadAndInstall,
              onDismiss: updates.later,
            ),
          ),
        );
      },
    ).then((_) {
      open = false;
      dialogContext = null;
      // Back or a tap outside: the same as Later. A new dialog state opens a new dialog.
      if (_isDialogState(updates.state.value)) updates.later();
    });
  }

  updates.state.addListener(onState);
  return () => updates.state.removeListener(onState);
}
