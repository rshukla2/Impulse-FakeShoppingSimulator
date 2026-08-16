import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake and simulated user-facing copy is limited to the PRD allowlist',
      () {
    const allowed = {
      'Fake Shopping Simulator',
      'This is a fake shopping experience. Nothing in your cart will actually be purchased or delivered. You will not be charged.',
      'This was a simulated order. You did not purchase anything, nothing will be delivered to your home, and no payment was made. We do not collect your address or card information.',
      'Simulated Order',
    };
    final textLiteral = RegExp(
      r'''Text\(\s*['"]([^'"]*(?:fake|simulated)[^'"]*)['"]''',
      caseSensitive: false,
      multiLine: true,
    );
    final found = <String>{};

    for (final root in ['lib/screens', 'lib/widgets']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        found.addAll(
          textLiteral.allMatches(source).map((match) => match.group(1)!),
        );
      }
    }

    expect(found, allowed);
  });
}
