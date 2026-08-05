import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// A single navigational row in the profile or settings tab.
///
/// Previously duplicated as `_ProfileTile` and `_ProviderProfileTile` with
/// identical bodies.
class ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;

  /// `null` renders the row disabled rather than silently doing nothing on
  /// tap — an unfinished destination should look unfinished.
  final VoidCallback? onTap;
  final bool isDestructive;
  final String? subtitle;

  const ProfileTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final enabled = onTap != null;

    final accent = isDestructive ? AppColors.error : AppColors.primary;
    final labelColor = isDestructive
        ? AppColors.error
        : (isDark ? Colors.white : AppColors.textPrimary);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: ListTile(
        onTap: onTap,
        enabled: enabled,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        title: Text(
          label,
          style: AppTextStyles.bodyLarge.copyWith(color: labelColor),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textHint,
          size: 20,
        ),
      ),
    );
  }
}
