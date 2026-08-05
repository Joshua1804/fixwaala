import 'package:flutter/material.dart';

import '../constants/legal_content.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Renders a titled block of static text — Privacy Policy, Terms, About, Help.
///
/// These four tiles were `onTap: () {}`. Privacy Policy and Terms of Service
/// are **Play Store submission requirements**, so their absence was a release
/// blocker, not a polish item.
///
/// Content is a light structured format rather than raw markdown, to avoid
/// pulling in a renderer for four screens.
class StaticContentScreen extends StatelessWidget {
  final StaticDocument document;

  const StaticContentScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          if (document.lastUpdated != null) ...[
            Text(
              'Last updated ${document.lastUpdated}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          for (final section in document.sections) ...[
            if (section.heading != null) ...[
              Text(section.heading!, style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              section.body,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}
