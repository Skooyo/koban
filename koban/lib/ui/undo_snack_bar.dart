import 'dart:developer' as developer;

import 'package:material_ui/material_ui.dart';

import '../data/undoable.dart';

/// How long the owner can take a delete back.
const undoDuration = Duration(seconds: 6);

const _undoFailed = 'Could not undo. Add it again by hand.';

/// Shows [message]. With [undo], the snackbar has an "Undo" button for [undoDuration].
/// Undo runs [Undoable.undo]. When the snackbar ends any other way, [Undoable.commit] runs.
/// Pass the messenger that you read before the page closed, so it shows after the page goes.
void showUndoSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  Undoable? undo,
}) {
  if (undo == null) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
    return;
  }
  // Each Undo shows only inside its own window. A new one ends the old one now.
  messenger.hideCurrentSnackBar();
  messenger
      .showSnackBar(
        SnackBar(
          content: Text(message),
          duration: undoDuration,
          // A snackbar with an action stays until a tap unless this is false.
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await undo.undo();
              } catch (e, s) {
                developer.log(
                  'Undo failed',
                  name: 'Undo',
                  error: e,
                  stackTrace: s,
                );
                messenger.showSnackBar(
                  const SnackBar(content: Text(_undoFailed)),
                );
              }
            },
          ),
        ),
      )
      .closed
      .then((reason) async {
        if (reason == SnackBarClosedReason.action) return;
        try {
          await undo.commit?.call();
        } catch (e, s) {
          developer.log('Commit failed', name: 'Undo', error: e, stackTrace: s);
        }
      });
}
