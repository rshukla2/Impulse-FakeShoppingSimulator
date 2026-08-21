import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fake and simulated user-facing copy is limited to the PRD allowlist',
      () {
    const allowed = {
      'Fake Shopping Simulator',
      'This is a fake shopping experience. Nothing in your cart will actually be purchased or delivered. You will not be charged. Saved masked card details and addresses remain only on this device.',
      'This was a simulated order. Nothing was purchased or delivered, and no payment was made. Your masked card details and addresses remain only on this device.',
      'This is a simulated payment method. No charge or authorization occurs. The complete card number is never saved or transmitted. Only the cardholder name, network, expiration, and last four digits remain on this device.',
      'No saved cards yet. Add a simulated card to use at checkout.',
      'Manage locally saved simulated cards',
      'Add a card to continue with this simulated order.',
      'Add an address to continue with this simulated order.',
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
