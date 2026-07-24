import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// The home screen's hero section: a deep-green gradient panel with a large
/// faint repair-themed icon standing in for imagery, a headline, optional
/// supporting copy, and a primary CTA.
class HeroBanner extends StatelessWidget {
  final String headline;
  final String? subheadline;
  final String ctaLabel;
  final VoidCallback onCtaTap;

  const HeroBanner({
    super.key,
    required this.headline,
    this.subheadline,
    required this.ctaLabel,
    required this.onCtaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.raised,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -16,
            bottom: -16,
            child: Icon(
              Icons.home_repair_service_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: AppTextStyles.headlineMedium.copyWith(
                  color: Colors.white,
                ),
              ),
              if (subheadline != null) ...[
                const SizedBox(height: 8),
                Text(
                  subheadline!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.button),
                child: InkWell(
                  onTap: onCtaTap,
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Text(
                      ctaLabel,
                      style: AppTextStyles.buttonText.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
