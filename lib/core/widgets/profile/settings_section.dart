import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A bordered card grouping one settings control.
///
/// Previously duplicated as `_SettingsSection` and `_ProviderSettingsSection`.
class SettingsSection extends StatelessWidget {
  final Widget child;

  const SettingsSection({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.glassBorderDark
              : AppColors.divider.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}
