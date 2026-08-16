import 'package:flutter/material.dart';
import 'package:impulse/core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Licenses & Credits'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildCreditCard(
            title: 'Wikimedia Commons & Wikidata',
            license:
                'Creative Commons Attribution-ShareAlike (CC BY-SA 4.0 / 3.0) & CC0',
            description:
                'Used for regional culinary dishes, menu items, dish photography, and open cultural food metadata. Specific photographer attributions are displayed on individual dish pages.',
            icon: LucideIcons.globe,
          ),
          const SizedBox(height: 14),
          _buildCreditCard(
            title: 'Open Food Facts',
            license: 'Open Database License (ODbL) v1.0',
            description:
                'Provides crowdsourced packaged grocery products, international packaging data, and localized snack/pantry items with open data compliance.',
            icon: LucideIcons.apple,
          ),
          const SizedBox(height: 14),
          _buildCreditCard(
            title: 'Open Icecat',
            license: 'Open Icecat Open Content License',
            description:
                'Open catalog distribution of consumer electronics, laptops, computer peripherals, and home technology products.',
            icon: LucideIcons.laptop,
          ),
          const SizedBox(height: 14),
          _buildCreditCard(
            title: 'Frankfurter API',
            license: 'Open Reference Rates by European Central Bank',
            description:
                'Real-time and cached currency exchange rates used for accurate local price conversion without tracking user coordinates.',
            icon: LucideIcons.coins,
          ),
          const SizedBox(height: 14),
          _buildCreditCard(
            title: 'Unsplash Photography',
            license: 'Unsplash License (Free commercial & non-commercial use)',
            description:
                'High quality product and imaginary item photos provided by the global creative community.',
            icon: LucideIcons.camera,
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard({
    required String title,
    required String license,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warmBeige,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.forestGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.forestGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warmBeigeLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              license,
              style: const TextStyle(
                color: AppColors.terracottaDark,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: AppColors.slateGreyDark,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
