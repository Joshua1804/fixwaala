import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// Consistent header (title + subtitle + trailing actions) above every admin
/// screen's content, inside [AdminShell]'s scrollable body area.
class AdminPageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  const AdminPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Every route here, including sidebar-to-sidebar (AdminShell._go), is
    // pushed rather than replaced, so this is true whenever there's
    // somewhere to return to.
    final canPop = Navigator.canPop(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canPop)
                Padding(
                  padding: const EdgeInsets.only(right: 4, top: 2),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headlineMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty)
                Wrap(spacing: AppSpacing.sm, children: actions),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          child,
        ],
      ),
    );
  }
}
