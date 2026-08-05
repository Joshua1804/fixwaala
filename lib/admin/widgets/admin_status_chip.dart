import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_text_styles.dart';

/// Common semantic tone for a status word, shared across every list/detail
/// screen so `active`, `open`, `suspended`, etc. all render consistently.
enum AdminTone { good, neutral, warning, bad }

/// A small colored pill for a status word (`active`, `suspended`, `open`,
/// `resolved`, ...).
class AdminStatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const AdminStatusChip({super.key, required this.label, required this.color});

  factory AdminStatusChip.semantic(String label, {required AdminTone tone}) {
    final color = switch (tone) {
      AdminTone.good => AppColors.success,
      AdminTone.neutral => AppColors.info,
      AdminTone.warning => AppColors.warning,
      AdminTone.bad => AppColors.error,
    };
    return AdminStatusChip(label: label, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
