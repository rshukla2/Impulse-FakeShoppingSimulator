import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/localized_pricing.dart';
import '../../models/cart_item.dart';
import '../../models/checkout_profile.dart';
import '../../models/order.dart';
import '../../providers/bootstrap_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_profiles_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/disclaimer_banner.dart';
import '../main_navigation_screen.dart';
import 'checkout_profile_forms.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isProcessing = false;
  SimulatedOrder? _completedOrder;
  CheckoutSnapshot? _completedSnapshot;
  String? _selectedCardId;
  String? _selectedShippingAddressId;
  String? _selectedBillingAddressId;
  bool _billingMatchesShipping = true;

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
    final profiles = ref.read(checkoutProfilesProvider);
    final cardId = _selectedCardId ?? profiles.data.defaultCardId;
    final shippingId =
        _selectedShippingAddressId ?? profiles.data.defaultShippingAddressId;
    final billingId = _billingMatchesShipping
        ? shippingId
        : _selectedBillingAddressId ?? profiles.data.defaultBillingAddressId;
    final card = _cardById(profiles, cardId);
    final shippingAddress = _addressById(profiles, shippingId);
    final billingAddress = _addressById(profiles, billingId);
    if (card == null || shippingAddress == null || billingAddress == null) {
      setState(() => _isProcessing = false);
      return;
    }
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

    final snapshot = CheckoutSnapshot(
      card: card,
      shippingAddress: shippingAddress,
      billingAddress: billingAddress,
      billingMatchesShipping: _billingMatchesShipping,
    );
    final snapshotSaved = await ref
        .read(checkoutProfilesProvider.notifier)
        .saveOrderSnapshot(order.id, snapshot);
    if (!snapshotSaved) {
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    await ref.read(ordersProvider.notifier).addOrder(order);
    await userNotifier.recordSimulatedOrder(
      orderTotalBaseUsd: totalBaseUsd,
      itemCount: itemCount,
    );
    ref.read(cartProvider.notifier).clearCart();

    if (!mounted) return;
    setState(() {
      _completedOrder = order;
      _completedSnapshot = snapshot;
      _isProcessing = false;
    });
  }

  PaymentCardProfile? _cardById(
    CheckoutProfilesState state,
    String? id,
  ) {
    for (final card in state.data.cards) {
      if (card.id == id) return card;
    }
    return state.data.cards.isEmpty ? null : state.data.cards.first;
  }

  AddressProfile? _addressById(
    CheckoutProfilesState state,
    String? id,
  ) {
    for (final address in state.data.addresses) {
      if (address.id == id) return address;
    }
    return state.data.addresses.isEmpty ? null : state.data.addresses.first;
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completedOrder;
    if (completed != null) {
      return _Confirmation(order: completed, snapshot: _completedSnapshot!);
    }

    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartSubtotalProvider);
    final bootstrap = ref.watch(bootstrapProvider).value;
    final currency = bootstrap?.currency ?? 'USD';
    final symbol = bootstrap?.currencySymbol ?? '\$';
    final formattedTotal = CurrencyFormatter.format(total, currency, symbol);
    final profiles = ref.watch(checkoutProfilesProvider);
    final card = _cardById(
      profiles,
      _selectedCardId ?? profiles.data.defaultCardId,
    );
    final shippingAddress = _addressById(
      profiles,
      _selectedShippingAddressId ?? profiles.data.defaultShippingAddressId,
    );
    final billingAddress = _billingMatchesShipping
        ? shippingAddress
        : _addressById(
            profiles,
            _selectedBillingAddressId ?? profiles.data.defaultBillingAddressId,
          );
    final checkoutReady = !profiles.isLoading &&
        profiles.errorMessage == null &&
        card != null &&
        shippingAddress != null &&
        billingAddress != null;

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
              const Divider(height: 36),
              _sectionTitle('Shipping Address'),
              const SizedBox(height: 10),
              if (profiles.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (profiles.errorMessage != null)
                _storageError(profiles.errorMessage!)
              else ...[
                _addressSelector(
                  profiles.data.addresses,
                  shippingAddress,
                  onChanged: (address) => setState(
                    () => _selectedShippingAddressId = address?.id,
                  ),
                ),
                _addButton(
                  label: 'Add Shipping Address',
                  icon: LucideIcons.mapPin,
                  onPressed: () => _addAddress(isBilling: false),
                ),
              ],
              const Divider(height: 36),
              _sectionTitle('Payment Method'),
              const SizedBox(height: 10),
              if (!profiles.isLoading && profiles.errorMessage == null) ...[
                _cardSelector(
                  profiles.data.cards,
                  card,
                  onChanged: (selected) =>
                      setState(() => _selectedCardId = selected?.id),
                ),
                _addButton(
                  label: 'Add Card',
                  icon: LucideIcons.creditCard,
                  onPressed: _addCard,
                ),
              ],
              const Divider(height: 36),
              _sectionTitle('Billing Address'),
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _billingMatchesShipping,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Same as shipping address'),
                onChanged: profiles.errorMessage == null
                    ? (value) => setState(
                          () => _billingMatchesShipping = value ?? true,
                        )
                    : null,
              ),
              if (!_billingMatchesShipping &&
                  !profiles.isLoading &&
                  profiles.errorMessage == null) ...[
                _addressSelector(
                  profiles.data.addresses,
                  billingAddress,
                  onChanged: (address) => setState(
                    () => _selectedBillingAddressId = address?.id,
                  ),
                ),
                _addButton(
                  label: 'Add Billing Address',
                  icon: LucideIcons.mapPin,
                  onPressed: () => _addAddress(isBilling: true),
                ),
              ],
              const Divider(height: 36),
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
                  onPressed: cart.isEmpty || _isProcessing || !checkoutReady
                      ? null
                      : _placeOrder,
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

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          color: AppColors.forestGreen,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      );

  Widget _storageError(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warmBeige,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () =>
                ref.read(checkoutProfilesProvider.notifier).reload(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _cardSelector(
    List<PaymentCardProfile> cards,
    PaymentCardProfile? selected, {
    required ValueChanged<PaymentCardProfile?> onChanged,
  }) {
    if (cards.isEmpty) {
      return const Text('Add a card to continue with this simulated order.');
    }
    return DropdownButtonFormField<PaymentCardProfile>(
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Saved Card'),
      items: cards
          .map(
            (card) => DropdownMenuItem(
              value: card,
              child: Text(
                '${card.maskedNumber} · ${card.formattedExpiry}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  Widget _addressSelector(
    List<AddressProfile> addresses,
    AddressProfile? selected, {
    required ValueChanged<AddressProfile?> onChanged,
  }) {
    if (addresses.isEmpty) {
      return const Text(
          'Add an address to continue with this simulated order.');
    }
    return DropdownButtonFormField<AddressProfile>(
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Saved Address'),
      items: addresses
          .map(
            (address) => DropdownMenuItem(
              value: address,
              child: Text(
                '${address.label} · ${address.addressLine1}, ${address.city}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  Widget _addButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  Future<void> _addCard() async {
    final card = await showCardProfileEditor(context, ref);
    if (card != null && mounted) {
      setState(() => _selectedCardId = card.id);
    }
  }

  Future<void> _addAddress({required bool isBilling}) async {
    final country =
        ref.read(bootstrapProvider).value?.countryName ?? 'United States';
    final address = await showAddressProfileEditor(
      context,
      ref,
      defaultCountry: country,
    );
    if (address != null && mounted) {
      setState(() {
        if (isBilling) {
          _selectedBillingAddressId = address.id;
        } else {
          _selectedShippingAddressId = address.id;
        }
      });
    }
  }
}

class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.order, required this.snapshot});

  final SimulatedOrder order;
  final CheckoutSnapshot snapshot;

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
                    'This was a simulated order. Nothing was purchased or delivered, and no payment was made. Your masked card details and addresses remain only on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.slateGreyDark,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SnapshotSummary(snapshot: snapshot),
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

class _SnapshotSummary extends StatelessWidget {
  const _SnapshotSummary({required this.snapshot});
  final CheckoutSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Card(
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
            Text(snapshot.card.maskedNumber),
            const SizedBox(height: 12),
            const Text(
              'Shipping Address',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(snapshot.shippingAddress.formattedLines.join('\n')),
            if (!snapshot.billingMatchesShipping) ...[
              const SizedBox(height: 12),
              const Text(
                'Billing Address',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(snapshot.billingAddress.formattedLines.join('\n')),
            ],
          ],
        ),
      ),
    );
  }
}
