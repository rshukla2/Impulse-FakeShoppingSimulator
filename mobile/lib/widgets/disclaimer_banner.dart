import 'package:flutter/material.dart';

import '../core/icons/app_icons.dart';
import '../core/theme/app_colors.dart';

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warmBeige,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warmBeigeDark),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 18, color: AppColors.forestGreen),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is a fake shopping experience. Nothing in your cart will actually be purchased or delivered. You will not be charged.',
              style: TextStyle(
                color: AppColors.slateGreyDark,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
