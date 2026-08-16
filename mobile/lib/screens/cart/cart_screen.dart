import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/localized_pricing.dart';
import '../../providers/bootstrap_provider.dart';
import '../../providers/cart_provider.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartSubtotalProvider);
    final bootstrap = ref.watch(bootstrapProvider).value;
    final currency = bootstrap?.currency ?? 'USD';
    final symbol = bootstrap?.currencySymbol ?? '\$';
    final formattedTotal = CurrencyFormatter.format(total, currency, symbol);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (cart.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              tooltip: 'Empty Cart',
              onPressed: () => _confirmEmptyCart(context, ref),
            ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: SafeArea(
                top: false,
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _totalRow('Subtotal', formattedTotal),
                        const SizedBox(height: 8),
                        _totalRow('Total', formattedTotal, emphasized: true),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CheckoutScreen(),
                              ),
                            ),
                            child: const Text('Proceed to Checkout'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: cart.isEmpty
          ? _EmptyCart(onBrowse: () => Navigator.of(context).pop())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    final localized = bootstrap == null
                        ? item.product
                        : localizeProduct(item.product, bootstrap);
                    final lineTotal = CurrencyFormatter.format(
                      localized.displayPrice * item.quantity,
                      currency,
                      symbol,
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warmBeigeLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: localized.imageUrl == null
                                  ? const ColoredBox(
                                      color: AppColors.warmBeige,
                                      child: Icon(
                                        LucideIcons.package,
                                        color: AppColors.forestGreen,
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: localized.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          const ColoredBox(
                                        color: AppColors.warmBeige,
                                        child: Icon(
                                          LucideIcons.package,
                                          color: AppColors.forestGreen,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  localized.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.forestGreen,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${localized.formattedPrice} each',
                                  style: const TextStyle(
                                    color: AppColors.slateGrey,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _quantityButton(
                                      tooltip: 'Decrease quantity',
                                      icon: LucideIcons.minus,
                                      onPressed: () => ref
                                          .read(cartProvider.notifier)
                                          .decrementQuantity(localized.id),
                                    ),
                                    Semantics(
                                      label:
                                          'Quantity ${item.quantity} for ${localized.name}',
                                      child: Text(
                                        '${item.quantity}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    _quantityButton(
                                      tooltip: 'Increase quantity',
                                      icon: LucideIcons.plus,
                                      onPressed: () => ref
                                          .read(cartProvider.notifier)
                                          .incrementQuantity(localized.id),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => ref
                                          .read(cartProvider.notifier)
                                          .removeItem(localized.id),
                                      icon: const Icon(
                                        LucideIcons.trash2,
                                        size: 17,
                                      ),
                                      label: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lineTotal,
                            style: const TextStyle(
                              color: AppColors.forestGreen,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }

  static Widget _totalRow(
    String label,
    String value, {
    bool emphasized = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasized ? AppColors.slateGreyDark : AppColors.slateGrey,
            fontSize: emphasized ? 16 : 14,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.forestGreen,
            fontSize: emphasized ? 20 : 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  static Widget _quantityButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton.outlined(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
    );
  }

  static Future<void> _confirmEmptyCart(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Cart?'),
        content: const Text('Remove every item from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empty Cart'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(cartProvider.notifier).clearCart();
    }
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.warmBeige,
              child: Icon(
                LucideIcons.shoppingCart,
                size: 44,
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: AppColors.forestGreen,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse the catalogs and add anything that catches your eye.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onBrowse,
              child: const Text('Browse Items'),
            ),
          ],
        ),
      ),
    );
  }
}
