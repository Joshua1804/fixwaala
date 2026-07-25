import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// A showcase card for a representative service offering: an icon standing
/// in for imagery, title, short description, starting price, and rating.
class PopularServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String startingPrice;
  final double rating;
  final VoidCallback onTap;

  const PopularServiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.startingPrice,
    required this.rating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Material(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card),
              boxShadow: AppShadows.card,
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.categoryIconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.categoryIconFg, size: 24),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: AppTextStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      startingPrice,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
