import 'package:material_ui/material_ui.dart';

import '../../data/qr_store.dart';
import '../../theme/koban_theme.dart';
import '../../ui/date_labels.dart';
import '../../ui/sheets.dart';
import '../../ui/undo_snack_bar.dart';
import 'person_view_model.dart';

/// The QR on a white box with a gold frame. White stays white in the dark theme, so the QR scans.
/// It is a picture, not a button.
class QrFrame extends StatelessWidget {
  const QrFrame({
    super.key,
    required this.image,
    required this.label,
    this.version = 0,
  });

  final ImageProvider image;
  final String label;

  /// It goes up when the file under the same path changes, so the picture loads again.
  final int version;

  Widget _square(BuildContext context, String? text) => AspectRatio(
    aspectRatio: 1,
    child: text == null
        ? null
        : Center(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleSmall!
                  .copyWith(color: Colors.black),
              textAlign: TextAlign.center,
            ),
          ),
  );

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: Theme.of(context).colorScheme.primary, width: 6),
    );
    return SizedBox(
      width: 240,
      child: Material(
        color: Colors.white,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Image(
            image: image,
            key: ValueKey(version),
            semanticLabel: label,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            // Still loading: keep the square so the layout does not jump.
            frameBuilder: (context, child, frame, sync) =>
                frame == null && !sync
                ? Stack(children: [_square(context, null), child])
                : child,
            errorBuilder: (context, error, stack) =>
                _square(context, "Couldn't load the QR. Use Replace QR below."),
          ),
        ),
      ),
    );
  }
}

/// "Added Fri, 13 Nov", or "Added" when the day is not known.
String qrAddedText(int? addedAt, DateTime now) =>
    addedAt == null ? 'Added' : 'Added ${dateLabel(addedAt, now)}';

/// The small QR picture of a QR row, on white so it stays a QR in the dark theme.
class QrThumb extends StatelessWidget {
  const QrThumb({super.key, required this.image, this.version = 0});

  final ImageProvider image;
  final int version;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Theme.of(context).colorScheme.primary),
    ),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Image(
        image: image,
        key: ValueKey(version),
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.qr_code_2, color: Colors.black),
      ),
    ),
  );
}

/// Shows the picked picture: "Use this picture?" with "Use as X's QR" and "Pick another".
/// It returns true for use, false for pick another, null when the owner closes it.
Future<bool?> showQrPreviewSheet(
  BuildContext context, {
  required String name,
  required String path,
}) => showKobanSheet<bool>(
  context: context,
  builder: (context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Use this picture?',
                style: weighted(theme.textTheme.titleLarge!, 800),
              ),
            ),
            Text(
              'Check that the whole QR shows and is sharp. '
              'A bank app cannot read a cut or blurred QR.',
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Center(
              child: QrFrame(
                image: qrImage(path),
                label: 'The picture you picked',
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              child: Text(
                name.isEmpty ? 'Use as their QR' : "Use as $name's QR",
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: theme.colorScheme.onSurface,
              ),
              child: const Text('Pick another'),
            ),
          ],
        ),
      ),
    );
  },
);

/// The one way to choose a QR: pick, check the picture, then use it or pick another.
/// It returns the path of the picture to use, or null when the owner cancels at the
/// picker or closes the check. A picture that is not used goes to [discard].
Future<String?> chooseQrPicture(
  BuildContext context, {
  required String name,
  required Future<String?> Function() pick,
  required Future<void> Function(String path) discard,
}) async {
  while (true) {
    final path = await pick();
    if (path == null) return null;
    if (!context.mounted) {
      await discard(path);
      return null;
    }
    final use = await showQrPreviewSheet(context, name: name, path: path);
    if (use == true) return path;
    await discard(path);
    if (use == null) return null;
  }
}

/// Picks and checks a picture, then saves it as the QR of [vm]. The result shows on
/// [messenger] with Undo for a replace. Use it where no sheet covers the page.
Future<void> replaceQrOnPage(
  BuildContext context,
  ScaffoldMessengerState messenger,
  PersonViewModel vm,
  String name,
) async {
  final path = await chooseQrPicture(
    context,
    name: name,
    pick: vm.pickQr,
    discard: vm.discardPick,
  );
  if (path == null) return;
  final (:saved, :undo) = await vm.replaceQr(path);
  if (!saved) return;
  showUndoSnackBar(
    messenger,
    undo == null ? 'QR added' : 'QR replaced',
    undo: undo,
  );
}
