import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import 'restaurant_card.dart';

/// Uses the phone list presentation on narrow screens and compact card columns
/// on wider screens.
class ResponsiveRestaurantList extends StatelessWidget {
  static const double desktopBreakpoint = 760;
  static const double desktopCardMaxWidth = 400;
  static const double desktopCardHeight = 320;

  final List<Restaurant> restaurants;

  const ResponsiveRestaurantList({
    super.key,
    required this.restaurants,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          if (constraints.crossAxisExtent < desktopBreakpoint) {
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => RestaurantCard(
                  key: ValueKey('restaurant-card-${restaurants[index].id}'),
                  restaurant: restaurants[index],
                ),
                childCount: restaurants.length,
              ),
            );
          }

          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: desktopCardMaxWidth,
              mainAxisExtent: desktopCardHeight,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => RestaurantCard(
                key: ValueKey('restaurant-card-${restaurants[index].id}'),
                restaurant: restaurants[index],
                margin: EdgeInsets.zero,
              ),
              childCount: restaurants.length,
            ),
          );
        },
      ),
    );
  }
}
