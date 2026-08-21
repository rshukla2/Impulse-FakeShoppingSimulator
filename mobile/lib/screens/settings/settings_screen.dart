import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/bootstrap_provider.dart';
import '../../providers/user_provider.dart';
import '../credits/credits_screen.dart';
import '../privacy/privacy_policy_screen.dart';
import 'addresses_screen.dart';
import 'wallet_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final bootstrap = ref.watch(bootstrapProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings & Privacy')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _sectionCard(
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.warmBeige,
                      child: Icon(
                        LucideIcons.user,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: AppColors.forestGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'Stored locally on this device',
                            style: TextStyle(
                              color: AppColors.slateGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.edit2),
                      tooltip: 'Edit display name',
                      onPressed: () => _editName(context, ref, user.name),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Country & Currency'),
              const SizedBox(height: 8),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          LucideIcons.globe,
                          color: AppColors.forestGreen,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Detected automatically',
                          style: TextStyle(
                            color: AppColors.forestGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _readOnlyRow(
                      'Country',
                      bootstrap?.countryName ?? 'United States',
                    ),
                    const SizedBox(height: 8),
                    _readOnlyRow(
                      'Currency',
                      '${bootstrap?.currency ?? 'USD'} (${bootstrap?.currencySymbol ?? '\$'})',
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Your country is inferred from the internet connection so catalog prices can use the local currency. Impulse does not use GPS. If the connection is unavailable, the last successful country and currency stay active.',
                      style: TextStyle(
                        color: AppColors.slateGrey,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Checkout Profiles'),
              const SizedBox(height: 8),
              Card(
                color: AppColors.warmBeigeLight,
                child: ListTile(
                  leading: const Icon(
                    LucideIcons.creditCard,
                    color: AppColors.forestGreen,
                  ),
                  title: const Text(
                    'Wallet',
                    style: TextStyle(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Manage locally saved simulated cards',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                color: AppColors.warmBeigeLight,
                child: ListTile(
                  leading: const Icon(
                    LucideIcons.mapPin,
                    color: AppColors.forestGreen,
                  ),
                  title: const Text(
                    'Addresses',
                    style: TextStyle(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Manage local shipping and billing addresses',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddressesScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Privacy'),
              const SizedBox(height: 8),
              _sectionCard(
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          LucideIcons.shieldCheck,
                          color: AppColors.forestGreen,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Local-first experience',
                          style: TextStyle(
                            color: AppColors.forestGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      '• No account or authentication required.\n'
                      '• Full card numbers are never saved or transmitted.\n'
                      '• Card security codes are never requested.\n'
                      '• Saved addresses and masked cards stay on this device.\n'
                      '• No payment processor, charge, or delivery.',
                      style: TextStyle(
                        color: AppColors.slateGreyDark,
                        fontSize: 12,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: AppColors.warmBeigeLight,
                child: ListTile(
                  leading: const Icon(
                    LucideIcons.shieldCheck,
                    color: AppColors.forestGreen,
                  ),
                  title: const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'How Impulse handles local and connection data',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: AppColors.warmBeigeLight,
                child: ListTile(
                  leading: const Icon(
                    LucideIcons.heartHandshake,
                    color: AppColors.forestGreen,
                  ),
                  title: const Text(
                    'Open Source & Image Credits',
                    style: TextStyle(
                      color: AppColors.forestGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Wikidata, Wikimedia, Open Food Facts & Icecat',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreditsScreen()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warmBeigeLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  static Widget _readOnlyRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.slateGrey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.slateGreyDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final controller = TextEditingController(text: name);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Enter name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await ref
                  .read(userProvider.notifier)
                  .setUserName(controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.forestGreen,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
