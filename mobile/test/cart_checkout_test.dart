import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/core/theme/app_theme.dart';
import 'package:impulse/models/product.dart';
import 'package:impulse/providers/bootstrap_provider.dart';
import 'package:impulse/providers/cart_provider.dart';
import 'package:impulse/providers/orders_provider.dart';
import 'package:impulse/providers/user_provider.dart';
import 'package:impulse/screens/cart/cart_screen.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cart removal and local checkout match the PRD', (tester) async {
    final prefs = await testPreferences({
      'impulse_user_name': 'Rishi',
      'impulse_is_onboarded': true,
    });
    final api = testApiClient((options, handler) {
      expect(options.path, '/bootstrap');
      resolveJson(
        options,
        handler,
        bootstrapJson(
          countryCode: 'GB',
          countryName: 'United Kingdom',
          currency: 'GBP',
          currencySymbol: '£',
          exchangeRate: 0.8,
        ),
      );
    });
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);

    const product = Product(
      id: 'product-1',
      type: 'shopping',
      name: 'Test Headphones',
      brand: 'Impulse Labs',
      category: 'Electronics',
      source: 'local',
      basePriceUsd: 10,
      displayPrice: 10,
      formattedPrice: '\$10.00',
      currency: 'USD',
      currencySymbol: '\$',
      rating: 4.5,
      reviewCount: 12,
    );
    container.read(cartProvider.notifier)
      ..addItem(product)
      ..addItem(product);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CartScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cart'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('£16.00'), findsNWidgets(3));
    expect(find.text('Proceed to Checkout'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);

    container.read(cartProvider.notifier)
      ..addItem(product)
      ..addItem(product);
    await tester.pump();
    await tester.tap(find.text('Proceed to Checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout'), findsOneWidget);
    expect(find.text('Order Total'), findsOneWidget);
    expect(find.text('You would spend: £16.00'), findsOneWidget);
    expect(
      find.text(
        'This is a fake shopping experience. Nothing in your cart will actually be purchased or delivered. You will not be charged.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'Place Order'), findsOneWidget);
    for (final forbidden in [
      'Card Number',
      'Payment Method',
      'Delivery Address',
      'Email',
      'Phone',
    ]) {
      expect(find.textContaining(forbidden), findsNothing);
    }

    final placeOrder = find.widgetWithText(ElevatedButton, 'Place Order');
    await tester.tap(placeOrder);
    await tester.tap(placeOrder);
    await tester.pumpAndSettle();

    expect(find.text('You saved £16.00 🎉'), findsOneWidget);
    expect(
      find.text(
        'Nice. You got the shopping experience without spending the money.',
      ),
      findsOneWidget,
    );
    expect(find.text('Continue Shopping'), findsOneWidget);
    expect(find.text('View Orders'), findsOneWidget);
    expect(container.read(cartProvider), isEmpty);
    expect(container.read(ordersProvider), hasLength(1));
    final order = container.read(ordersProvider).single;
    expect(order.currency, 'GBP');
    expect(order.formattedTotal, '£16.00');
    expect(order.totalBaseUsd, 20);
    expect(order.items.single.product.currency, 'GBP');
    expect(container.read(userProvider).lifetimeMoneySavedUsd, 20);
  });
}
