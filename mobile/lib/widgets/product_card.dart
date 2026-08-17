import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impulse/core/icons/app_icons.dart';
import '../core/theme/app_colors.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../screens/product/product_detail_screen.dart';
import 'app_network_image.dart';

class ProductCard extends ConsumerWidget {
  /// Shared grid ratio leaves enough vertical room for a brand, a two-line
  /// title, both price lines, and the add button on narrow phone columns.
  /// Larger accessibility text receives proportionally more card height.
  static double gridAspectRatioFor(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final accessibilityAdjustment =
        ((textScale - 1).clamp(0.0, 0.4) * 0.35).toDouble();
    return (0.64 - accessibilityAdjustment).clamp(0.50, 0.64).toDouble();
  }

  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.warmBeigeLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section with fictional badge or discount
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.15,
                  child:
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? AppNetworkImage(
                              imageUrl: product.imageUrl!,
                              cacheWidth: 600,
                              cacheHeight: 520,
                              fit: BoxFit.cover,
                              semanticLabel: product.name,
                              placeholderBuilder: (_) => Container(
                                color: AppColors.warmBeigeLight,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.forestGreen,
                                  ),
                                ),
                              ),
                              errorBuilder: (_) => Container(
                                color: AppColors.warmBeige,
                                child: const Icon(
                                  LucideIcons.package,
                                  size: 32,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.warmBeige,
                              child: const Icon(
                                LucideIcons.package,
                                size: 32,
                                color: AppColors.forestGreen,
                              ),
                            ),
                ),
                if (product.isFictional)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.terracotta,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.sparkles,
                              size: 10, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Imaginary Original',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Details section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.brand != null && product.brand!.isNotEmpty)
                          Text(
                            product.brand!.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.slateGreyLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          style: const TextStyle(
                            color: AppColors.forestGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.formattedOriginalPrice != null)
                                Text(
                                  product.formattedOriginalPrice!,
                                  style: const TextStyle(
                                    color: AppColors.slateGreyLight,
                                    fontSize: 11,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              Text(
                                product.formattedPrice,
                                style: const TextStyle(
                                  color: AppColors.slateGreyDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            ref.read(cartProvider.notifier).addItem(product);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Added "${product.name}" to cart'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.forestGreen,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              LucideIcons.plus,
                              size: 16,
                              color: AppColors.warmBeige,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
