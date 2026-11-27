/// What a delete gives back so the owner can take it back for a short time.
/// [undo] restores the rows with the same ids and links, in one transaction.
/// [commit] runs when the time ends without an Undo. It finishes work that must not
/// be undone, such as the delete of a file. [changed] is how many rows the Undo puts back,
/// for a message that says what Undo does.
class Undoable {
  const Undoable({required this.undo, this.commit, this.changed = 0});

  final int changed;

  final Future<void> Function() undo;
  final Future<void> Function()? commit;
}
