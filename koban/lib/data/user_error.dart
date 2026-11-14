/// An error whose [message] a screen shows to the user.
/// It replaces the Kotlin `IllegalArgumentException` and `IllegalStateException`
/// messages of the 0.1.1 repositories.
class KobanUserError implements Exception {
  const KobanUserError(this.message);

  final String message;

  @override
  String toString() => message;
}
