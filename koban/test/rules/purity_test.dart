import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rule files import no Flutter and no platform library', () {
    final bad = RegExp(
      r'''(import|export)\s+['"](package:flutter|dart:io|dart:ui|dart:html)''',
    );
    final files = Directory('lib/rules')
        .listSync(recursive: true)
        .whereType<File>()
        .followedBy([File('lib/theme/tokens.dart')]);
    final offenders = [
      for (final f in files)
        if (bad.hasMatch(f.readAsStringSync())) f.path,
    ];
    expect(offenders, isEmpty);
  });
}
