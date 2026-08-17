import 'package:flutter/material.dart';
import 'package:impulse/core/icons/app_icons.dart';
import '../core/theme/app_colors.dart';
import '../models/restaurant.dart';
import '../screens/food/restaurant_detail_screen.dart';
import 'app_network_image.dart';

class RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final EdgeInsetsGeometry margin;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
          ),
        );
      },
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          color: AppColors.warmBeigeLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 2.1,
                  child: restaurant.imageUrl != null
                      ? AppNetworkImage(
                          imageUrl: restaurant.imageUrl!,
                          cacheWidth: 960,
                          cacheHeight: 480,
                          fit: BoxFit.cover,
                          semanticLabel: restaurant.name,
                          placeholderBuilder: (_) =>
                              Container(color: AppColors.warmBeigeLight),
                          errorBuilder: (_) =>
                              Container(color: AppColors.warmBeige),
                        )
                      : Container(color: AppColors.warmBeige),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.star,
                            size: 12, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.forestGreen,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        restaurant.priceLevel,
                        style: const TextStyle(
                          color: AppColors.slateGreyLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${restaurant.cuisine} • ${(restaurant.reviewCount / 1000).toStringAsFixed(1)}K reviews',
                    style: const TextStyle(
                      color: AppColors.slateGrey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (restaurant.tagline != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      restaurant.tagline!,
                      style: const TextStyle(
                        color: AppColors.slateGreyLight,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
