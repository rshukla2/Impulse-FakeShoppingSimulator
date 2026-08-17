import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impulse/core/icons/app_icons.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/user_provider.dart';
import '../../providers/bootstrap_provider.dart';
import '../../widgets/badge_icon.dart';
import '../../widgets/impulse_toolbar_title.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  final ValueChanged<int> onSelectTab;

  const HomeScreen({super.key, required this.onSelectTab});

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final bootstrap = ref.watch(bootstrapProvider).value;
    final currency = bootstrap?.currency ?? 'USD';
    final symbol = bootstrap?.currencySymbol ?? '\$';

    final displayedSaved =
        user.lifetimeMoneySavedUsd * (bootstrap?.exchangeRate ?? 1.0);
    final formattedSaved =
        CurrencyFormatter.format(displayedSaved, currency, symbol);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const ImpulseToolbarTitle(),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const CartBadgeButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ApiConstants.isDeploymentPreview) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warmBeige,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.warmBeigeDark),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.info,
                      color: AppColors.forestGreen,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Deployment preview: the catalog service is being connected. Login, Home, and navigation are ready; live catalogs will appear after the API is deployed.',
                        style: TextStyle(
                          color: AppColors.slateGreyDark,
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Time of day greeting
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getTimeGreeting()}, ${user.name} 👋',
                        style: const TextStyle(
                          color: AppColors.forestGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Money saved by not buying anything:',
                        style: TextStyle(
                          color: AppColors.slateGrey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Lifetime Stats Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.forestGreen,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.forestGreen.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL MONEY SAVED',
                        style: TextStyle(
                          color: AppColors.warmBeige,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Icon(LucideIcons.piggyBank,
                          color: AppColors.warmBeige, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formattedSaved,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0x33F5E6CC), height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Orders Placed',
                              style: TextStyle(
                                color: AppColors.warmBeigeLight,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.fakeOrdersCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                          height: 36, width: 1, color: const Color(0x33F5E6CC)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Items Not Bought',
                              style: TextStyle(
                                color: AppColors.warmBeigeLight,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.itemsNotBoughtCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Catalog Shortcuts
            const Text(
              'Browse Catalogs',
              style: TextStyle(
                color: AppColors.forestGreen,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _buildCategoryShortcut(
              context: context,
              title: 'Food & Restaurants',
              subtitle: 'Fictional eateries, regional dishes & menus',
              icon: LucideIcons.utensils,
              color: const Color(0xFFE8F0E4),
              iconColor: AppColors.forestGreen,
              targetTabIndex: 1,
            ),
            const SizedBox(height: 12),
            _buildCategoryShortcut(
              context: context,
              title: 'Groceries',
              subtitle: 'Country-prioritized snacks, dairy, drinks & pantry',
              icon: LucideIcons.groceries,
              color: AppColors.warmBeige,
              iconColor: AppColors.forestGreen,
              targetTabIndex: 2,
            ),
            const SizedBox(height: 12),
            _buildCategoryShortcut(
              context: context,
              title: 'General Shopping',
              subtitle: 'Electronics, gadgets & hilarious fictional items',
              icon: LucideIcons.shoppingBag,
              color: const Color(0xFFFBECE8),
              iconColor: AppColors.terracotta,
              targetTabIndex: 3,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryShortcut({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required int targetTabIndex,
  }) {
    return InkWell(
      onTap: () {
        onSelectTab(targetTabIndex);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warmBeigeLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.forestGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.slateGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                color: AppColors.slateGreyLight, size: 20),
          ],
        ),
      ),
    );
  }
}
