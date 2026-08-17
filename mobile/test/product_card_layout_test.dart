import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/core/theme/app_theme.dart';
import 'package:impulse/models/product.dart';
import 'package:impulse/providers/user_provider.dart';
import 'package:impulse/widgets/product_card.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'narrow product card fits two-line title and both prices without overflow',
      (tester) async {
    final prefs = await testPreferences();
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    const cardWidth = 173.0;
    const product = Product(
      id: 'two-line-card',
      type: 'shopping',
      name: 'A deliberately long catalog product title',
      brand: 'Example Brand',
      category: 'Shopping',
      source: 'test',
      basePriceUsd: 19.99,
      originalPriceUsd: 24.44,
      displayPrice: 19.99,
      originalDisplayPrice: 24.44,
      formattedPrice: '\$19.99',
      formattedOriginalPrice: '\$24.44',
      currency: 'USD',
      currencySymbol: '\$',
      rating: 4.5,
      reviewCount: 100,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                textScaler: TextScaler.linear(1.2),
              ),
              child: Center(
                child: Builder(
                  builder: (context) => SizedBox(
                    width: cardWidth,
                    height: cardWidth / ProductCard.gridAspectRatioFor(context),
                    child: const ProductCard(product: product),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(product.name), findsOneWidget);
    expect(find.text(product.formattedOriginalPrice!), findsOneWidget);
    expect(find.text(product.formattedPrice), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
