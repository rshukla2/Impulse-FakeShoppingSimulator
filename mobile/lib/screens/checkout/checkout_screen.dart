import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/localized_pricing.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../providers/bootstrap_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/disclaimer_banner.dart';
import '../main_navigation_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isProcessing = false;
  SimulatedOrder? _completedOrder;

  Future<void> _placeOrder() async {
    if (_isProcessing || ref.read(cartProvider).isEmpty) return;
    setState(() => _isProcessing = true);

    final cart = ref.read(cartProvider);
    final bootstrap = ref.read(bootstrapProvider).value;
    final currency = bootstrap?.currency ?? 'USD';
    final symbol = bootstrap?.currencySymbol ?? '\$';
    final total = ref.read(cartSubtotalProvider);
    final totalBaseUsd = ref.read(cartBaseTotalUsdProvider);
    final itemCount = ref.read(cartItemCountProvider);
    final items = cart
        .map(
          (item) => CartItem(
            product: bootstrap == null
                ? item.product
                : localizeProduct(item.product, bootstrap),
            quantity: item.quantity,
          ),
        )
        .toList(growable: false);
    final now = DateTime.now();
    // Initialize the canonical savings state before persisting the new order,
    // so a first read cannot mistake this order for legacy history to migrate.
    final userNotifier = ref.read(userProvider.notifier);
    final order = SimulatedOrder(
      id: 'ORD-${now.millisecondsSinceEpoch}',
      createdAt: now,
      items: items,
      totalAmount: total,
      formattedTotal: CurrencyFormatter.format(total, currency, symbol),
      currency: currency,
      currencySymbol: symbol,
      totalItemsCount: itemCount,
      totalBaseUsd: totalBaseUsd,
    );

    await ref.read(ordersProvider.notifier).addOrder(order);
    await userNotifier.recordSimulatedOrder(
      orderTotalBaseUsd: totalBaseUsd,
      itemCount: itemCount,
    );
    ref.read(cartProvider.notifier).clearCart();

    if (!mounted) return;
    setState(() {
      _completedOrder = order;
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completedOrder;
    if (completed != null) return _Confirmation(order: completed);

    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartSubtotalProvider);
    final bootstrap = ref.watch(bootstrapProvider).value;
    final currency = bootstrap?.currency ?? 'USD';
    final symbol = bootstrap?.currencySymbol ?? '\$';
    final formattedTotal = CurrencyFormatter.format(total, currency, symbol);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Item Summary',
                style: TextStyle(
                  color: AppColors.forestGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...cart.map((item) {
                final product = bootstrap == null
                    ? item.product
                    : localizeProduct(item.product, bootstrap);
                final lineTotal = CurrencyFormatter.format(
                  product.displayPrice * item.quantity,
                  currency,
                  symbol,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('${item.quantity} × ${product.name}')),
                      const SizedBox(width: 12),
                      Text(
                        lineTotal,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order Total',
                    style: TextStyle(
                      color: AppColors.forestGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    formattedTotal,
                    style: const TextStyle(
                      color: AppColors.forestGreen,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'You would spend: $formattedTotal',
                style: const TextStyle(
                  color: AppColors.slateGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              const DisclaimerBanner(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: cart.isEmpty || _isProcessing ? null : _placeOrder,
                  child: _isProcessing
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.warmBeige,
                          ),
                        )
                      : const Text('Place Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.order});

  final SimulatedOrder order;

  void _openTab(BuildContext context, int tab) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(initialIndex: tab),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 40),
                const CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.forestGreen,
                  child: Icon(
                    LucideIcons.check,
                    size: 44,
                    color: AppColors.warmBeige,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'You saved ${order.formattedTotal} 🎉',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.forestGreen,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Nice. You got the shopping experience without spending the money.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.slateGreyDark,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warmBeige,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.warmBeigeDark),
                  ),
                  child: const Text(
                    'This was a simulated order. You did not purchase anything, nothing will be delivered to your home, and no payment was made. We do not collect your address or card information.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.slateGreyDark,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _openTab(context, 3),
                  child: const Text('Continue Shopping'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _openTab(context, 4),
                  child: const Text('View Orders'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
