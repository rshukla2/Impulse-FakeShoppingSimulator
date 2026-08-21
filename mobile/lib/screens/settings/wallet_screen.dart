import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../models/checkout_profile.dart';
import '../../providers/checkout_profiles_provider.dart';
import '../checkout/checkout_profile_forms.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkoutProfilesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Wallet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.isLoading || state.errorMessage != null
            ? null
            : () => showCardProfileEditor(context, ref),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Card'),
      ),
      body: _body(context, ref, state),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    CheckoutProfilesState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return _StorageError(message: state.errorMessage!);
    }
    if (state.data.cards.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No saved cards yet. Add a simulated card to use at checkout.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          itemCount: state.data.cards.length,
          itemBuilder: (context, index) {
            final card = state.data.cards[index];
            final isDefault = card.id == state.data.defaultCardId;
            return Card(
              color: AppColors.warmBeigeLight,
              child: ListTile(
                leading: const Icon(
                  LucideIcons.creditCard,
                  color: AppColors.forestGreen,
                ),
                title: Text(card.maskedNumber),
                subtitle: Text(
                  '${card.cardholderName} · Expires ${card.formattedExpiry}${isDefault ? ' · Default' : ''}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) => _handleAction(
                    context,
                    ref,
                    card,
                    action,
                  ),
                  itemBuilder: (_) => [
                    if (!isDefault)
                      const PopupMenuItem(
                        value: 'default',
                        child: Text('Set as default'),
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
    PaymentCardProfile card,
    String action,
  ) async {
    if (action == 'default') {
      await ref.read(checkoutProfilesProvider.notifier).setDefaultCard(card.id);
    } else if (action == 'edit') {
      if (context.mounted) {
        await showCardProfileEditor(context, ref, existing: card);
      }
    } else if (action == 'delete') {
      await ref.read(checkoutProfilesProvider.notifier).deleteCard(card.id);
    }
  }
}

class _StorageError extends ConsumerWidget {
  const _StorageError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
