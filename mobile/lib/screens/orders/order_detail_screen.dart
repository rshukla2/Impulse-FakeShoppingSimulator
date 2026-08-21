import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/order.dart';
import '../../providers/checkout_profiles_provider.dart';
import '../../widgets/app_network_image.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.order});

  final SimulatedOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot =
        ref.watch(checkoutProfilesProvider).data.orderSnapshots[order.id];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Order Details')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ${order.id}',
                        style: const TextStyle(
                          color: AppColors.forestGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        DateFormat('MMMM d, yyyy • h:mm a')
                            .format(order.createdAt),
                        style: const TextStyle(color: AppColors.slateGrey),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.terracotta,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Simulated Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...order.items.map((item) {
                final unitPrice = CurrencyFormatter.format(
                  item.product.displayPrice,
                  order.currency,
                  order.currencySymbol,
                );
                final lineTotal = CurrencyFormatter.format(
                  item.product.displayPrice * item.quantity,
                  order.currency,
                  order.currencySymbol,
                );
                return Card(
                  color: AppColors.warmBeigeLight,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: item.product.imageUrl == null
                                ? const ColoredBox(
                                    color: AppColors.warmBeige,
                                    child: Icon(
                                      LucideIcons.package,
                                      color: AppColors.forestGreen,
                                    ),
                                  )
                                : AppNetworkImage(
                                    imageUrl: item.product.imageUrl!,
                                    cacheWidth: 160,
                                    cacheHeight: 160,
                                    fit: BoxFit.cover,
                                    semanticLabel: item.product.name,
                                    placeholderBuilder: (_) => const ColoredBox(
                                      color: AppColors.warmBeigeLight,
                                    ),
                                    errorBuilder: (_) => const ColoredBox(
                                      color: AppColors.warmBeige,
                                      child: Icon(
                                        LucideIcons.package,
                                        color: AppColors.forestGreen,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  color: AppColors.forestGreen,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('$unitPrice × ${item.quantity}'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lineTotal,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (snapshot != null) ...[
                const SizedBox(height: 8),
                Card(
                  color: AppColors.warmBeigeLight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Checkout Details',
                          style: TextStyle(
                            color: AppColors.forestGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.creditCard,
                              color: AppColors.forestGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(snapshot.card.maskedNumber),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Shipping Address',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                            snapshot.shippingAddress.formattedLines.join('\n')),
                        if (!snapshot.billingMatchesShipping) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Billing Address',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(snapshot.billingAddress.formattedLines
                              .join('\n')),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: AppColors.forestGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    order.formattedTotal,
                    style: const TextStyle(
                      color: AppColors.forestGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
