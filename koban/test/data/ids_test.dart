import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/ids.dart';

void main() {
  test('new ids have the form of a Java random UUID', () {
    final ids = List.generate(100, (_) => newId());
    for (final id in ids) {
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    }
    expect(ids.toSet().length, 100);
  });
}
