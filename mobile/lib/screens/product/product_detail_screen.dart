import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:impulse/core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/badge_icon.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(product.name),
        actions: const [
          CartBadgeButton(),
          SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL PRICE',
                      style: TextStyle(
                        color: AppColors.slateGreyLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          product.formattedPrice,
                          style: const TextStyle(
                            color: AppColors.forestGreen,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product.formattedOriginalPrice != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            product.formattedOriginalPrice!,
                            style: const TextStyle(
                              color: AppColors.slateGreyLight,
                              fontSize: 14,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('Add to Cart'),
                  onPressed: () {
                    ref.read(cartProvider.notifier).addItem(product);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "${product.name}" to cart'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.forestGreen,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with Fictional / Discount badge
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.2,
                  child:
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: product.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppColors.warmBeigeLight),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.warmBeige,
                                child: const Icon(LucideIcons.package,
                                    size: 48, color: AppColors.forestGreen),
                              ),
                            )
                          : Container(
                              color: AppColors.warmBeige,
                              child: const Icon(LucideIcons.package,
                                  size: 48, color: AppColors.forestGreen),
                            ),
                ),
                if (product.isFictional)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.terracotta,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.sparkles,
                              size: 12, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Imaginary Original',
                            style: TextStyle(
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand & Category
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (product.brand != null)
                        Text(
                          product.brand!.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.terracottaDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warmBeige,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.category,
                          style: const TextStyle(
                            color: AppColors.forestGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    product.name,
                    style: const TextStyle(
                      color: AppColors.forestGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Rating & Reviews
                  Row(
                    children: [
                      const Icon(LucideIcons.star,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: AppColors.slateGreyDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${product.reviewCount} reviews)',
                        style: const TextStyle(
                          color: AppColors.slateGreyLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Description
                  const Text(
                    'About this item',
                    style: TextStyle(
                      color: AppColors.forestGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description ??
                        'No description is available for this catalog item.',
                    style: const TextStyle(
                      color: AppColors.slateGreyDark,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Attribution & Open Source Meta
                  if (product.imageAttribution != null ||
                      product.imageLicense != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warmBeigeLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.info,
                                  size: 14, color: AppColors.slateGrey),
                              SizedBox(width: 6),
                              Text(
                                'Data & Image Attribution',
                                style: TextStyle(
                                  color: AppColors.forestGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (product.imageAttribution != null)
                            Text(
                              'Photo: ${product.imageAttribution}',
                              style: const TextStyle(
                                color: AppColors.slateGrey,
                                fontSize: 11,
                              ),
                            ),
                          if (product.imageLicense != null)
                            Text(
                              'License: ${product.imageLicense}',
                              style: const TextStyle(
                                color: AppColors.slateGrey,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
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
