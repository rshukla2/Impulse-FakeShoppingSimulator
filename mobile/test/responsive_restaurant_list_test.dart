import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impulse/models/restaurant.dart';
import 'package:impulse/widgets/responsive_restaurant_list.dart';

void main() {
  const restaurants = [
    Restaurant(
      id: 'one',
      name: 'Restaurant One',
      cuisine: 'Italian',
      tagline: 'A neighborhood favorite',
      rating: 4.8,
      reviewCount: 1200,
      priceLevel: r'$$',
    ),
    Restaurant(
      id: 'two',
      name: 'Restaurant Two',
      cuisine: 'Japanese',
      tagline: 'Fresh dishes every day',
      rating: 4.7,
      reviewCount: 900,
      priceLevel: r'$$',
    ),
    Restaurant(
      id: 'three',
      name: 'Restaurant Three',
      cuisine: 'Mexican',
      tagline: 'Bright and bold flavors',
      rating: 4.9,
      reviewCount: 1800,
      priceLevel: r'$$$',
    ),
  ];

  Future<void> pumpAtSize(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ResponsiveRestaurantList(restaurants: restaurants),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('desktop restaurant results use compact multi-column cards',
      (tester) async {
    await pumpAtSize(tester, const Size(1200, 900));

    final first =
        tester.getRect(find.byKey(const ValueKey('restaurant-card-one')));
    final second =
        tester.getRect(find.byKey(const ValueKey('restaurant-card-two')));
    final third =
        tester.getRect(find.byKey(const ValueKey('restaurant-card-three')));

    expect(first.width,
        lessThanOrEqualTo(ResponsiveRestaurantList.desktopCardMaxWidth));
    expect(first.height, ResponsiveRestaurantList.desktopCardHeight);
    expect(first.top, second.top);
    expect(second.top, third.top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone restaurant results remain a single-column list',
      (tester) async {
    await pumpAtSize(tester, const Size(390, 844));

    final first =
        tester.getRect(find.byKey(const ValueKey('restaurant-card-one')));
    final second =
        tester.getRect(find.byKey(const ValueKey('restaurant-card-two')));

    expect(first.left, second.left);
    expect(second.top, greaterThanOrEqualTo(first.bottom));
    expect(tester.takeException(), isNull);
  });
}
