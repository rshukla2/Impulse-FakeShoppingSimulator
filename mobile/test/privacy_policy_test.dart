import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/screens/privacy/privacy_policy_screen.dart';

void main() {
  testWidgets('privacy policy is readable inside the app', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyPolicyScreen()),
    );

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Effective date: August 17, 2026'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('No accounts, payments, or addresses'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('No accounts, payments, or addresses'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Country and currency selection'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Country and currency selection'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Contact'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.textContaining('rishishukla2k@gmail.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('public HTML policy is static and complete', () {
    final html = File('web/privacy-policy/index.html').readAsStringSync();

    expect(html, contains('<title>Privacy Policy | Impulse</title>'));
    expect(html, contains('Rishi Shukla'));
    expect(html, contains('rishishukla2k@gmail.com'));
    expect(html, contains('IP address is not retained'));
    expect(html, isNot(contains('<script')));
  });
}
