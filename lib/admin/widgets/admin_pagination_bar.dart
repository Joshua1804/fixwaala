import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Cursor-style pagination (Previous/Next), matched to how Firestore actually
/// paginates — by query cursor, not by offset/page-number. The caller owns
/// the cursor stack and just reports whether each direction is currently
/// possible.
class AdminPaginationBar extends StatelessWidget {
  final int pageNumber;
  final int pageSize;
  final int currentCount;
  final bool hasPrevious;
  final bool hasNext;
  final bool isLoading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const AdminPaginationBar({
    super.key,
    required this.pageNumber,
    required this.pageSize,
    required this.currentCount,
    required this.hasPrevious,
    required this.hasNext,
    required this.isLoading,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page $pageNumber · $currentCount shown',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: (hasPrevious && !isLoading) ? onPrevious : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Previous'),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: (hasNext && !isLoading) ? onNext : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                label: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
