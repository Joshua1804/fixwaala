import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A colored pill-shaped badge for displaying status labels.
///
/// Used for ticket status, verification status, online/offline indicators.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final bool small;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.icon,
    this.small = false,
  });

  // ── Factory constructors for common statuses ────────────────────
  factory StatusBadge.success(String label, {IconData? icon}) =>
      StatusBadge(label: label, color: AppColors.success, icon: icon);

  factory StatusBadge.warning(String label, {IconData? icon}) =>
      StatusBadge(label: label, color: AppColors.warning, icon: icon);

  factory StatusBadge.error(String label, {IconData? icon}) =>
      StatusBadge(label: label, color: AppColors.error, icon: icon);

  factory StatusBadge.info(String label, {IconData? icon}) =>
      StatusBadge(label: label, color: AppColors.info, icon: icon);

  factory StatusBadge.neutral(String label, {IconData? icon}) =>
      StatusBadge(label: label, color: AppColors.textHint, icon: icon);

  factory StatusBadge.online() => const StatusBadge(
    label: 'Online',
    color: AppColors.success,
    icon: Icons.circle,
    small: true,
  );

  factory StatusBadge.offline() => const StatusBadge(
    label: 'Offline',
    color: AppColors.textHint,
    icon: Icons.circle,
    small: true,
  );

  factory StatusBadge.verified() => const StatusBadge(
    label: 'Verified',
    color: AppColors.success,
    icon: Icons.verified,
  );

  factory StatusBadge.pending() => const StatusBadge(
    label: 'Pending',
    color: AppColors.warning,
    icon: Icons.schedule,
  );

  @override
  Widget build(BuildContext context) {
    final bgColor = (color ?? AppColors.primary).withValues(alpha: 0.12);
    final fgColor = textColor ?? color ?? AppColors.primary;
    final hPad = small ? 8.0 : 10.0;
    final vPad = small ? 3.0 : 5.0;
    final iconSize = small ? 6.0 : 12.0;
    final style = small ? AppTextStyles.caption : AppTextStyles.labelSmall;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fgColor),
            SizedBox(width: small ? 4 : 5),
          ],
          Text(
            label,
            style: style.copyWith(color: fgColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
