import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/checkout_profile.dart';
import '../../providers/bootstrap_provider.dart';
import '../../providers/checkout_profiles_provider.dart';
import '../checkout/checkout_profile_forms.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkoutProfilesProvider);
    final country =
        ref.watch(bootstrapProvider).value?.countryName ?? 'United States';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLoading || state.errorMessage != null
            ? null
            : () => showAddressProfileEditor(
                  context,
                  ref,
                  defaultCountry: country,
                ),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Address'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
              ? _error(context, ref, state.errorMessage!)
              : state.data.addresses.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No saved addresses yet. Add one to use at checkout.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _addressList(context, ref, state, country),
    );
  }

  Widget _addressList(
    BuildContext context,
    WidgetRef ref,
    CheckoutProfilesState state,
    String country,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: state.data.addresses.length,
          itemBuilder: (context, index) {
            final address = state.data.addresses[index];
            final shipping = address.id == state.data.defaultShippingAddressId;
            final billing = address.id == state.data.defaultBillingAddressId;
            final defaults = [
              if (shipping) 'Default shipping',
              if (billing) 'Default billing',
            ].join(' · ');
            return Card(
              color: AppColors.warmBeigeLight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        LucideIcons.mapPin,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address.label,
                            style: const TextStyle(
                              color: AppColors.forestGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(address.formattedLines.join('\n')),
                          if (defaults.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              defaults,
                              style: const TextStyle(
                                color: AppColors.forestGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) => _handleAction(
                        context,
                        ref,
                        address,
                        action,
                        country,
                      ),
                      itemBuilder: (_) => [
                        if (!shipping)
                          const PopupMenuItem(
                            value: 'shipping',
                            child: Text('Set as default shipping'),
                          ),
                        if (!billing)
                          const PopupMenuItem(
                            value: 'billing',
                            child: Text('Set as default billing'),
                          ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    AddressProfile address,
    String action,
    String country,
  ) async {
    final notifier = ref.read(checkoutProfilesProvider.notifier);
    if (action == 'shipping') {
      await notifier.setDefaultShippingAddress(address.id);
    } else if (action == 'billing') {
      await notifier.setDefaultBillingAddress(address.id);
    } else if (action == 'edit') {
      if (context.mounted) {
        await showAddressProfileEditor(
          context,
          ref,
          existing: address,
          defaultCountry: country,
        );
      }
    } else if (action == 'delete') {
      await notifier.deleteAddress(address.id);
    }
  }

  Widget _error(BuildContext context, WidgetRef ref, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  ref.read(checkoutProfilesProvider.notifier).reload(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
