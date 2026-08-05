import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import 'services/admin_monitoring_service.dart';

class AdminMonitoringScreen extends StatefulWidget {
  const AdminMonitoringScreen({super.key});

  @override
  State<AdminMonitoringScreen> createState() => _AdminMonitoringScreenState();
}

class _AdminMonitoringScreenState extends State<AdminMonitoringScreen> {
  late Future<List<CollectionHealth>> _future;

  @override
  void initState() {
    super.initState();
    _future = AdminMonitoringService.instance.load();
  }

  void _retry() => setState(() {
    _future = AdminMonitoringService.instance.load();
  });

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Monitoring',
      subtitle: 'What is actually deployed and running for this project.',
      actions: [
        OutlinedButton.icon(
          onPressed: _retry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Backend', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          _BackendRow(
            label: 'Firestore rules & indexes',
            deployed: true,
            note: 'Live — every read/write in this app depends on them.',
          ),
          _BackendRow(
            label: 'Cloud Functions (aiTriage, scheduled jobs, push triggers)',
            deployed: AppConstants.scheduledFunctionsDeployed,
            note: AppConstants.scheduledFunctionsDeployed
                ? 'Deployed.'
                : 'Not deployed — requires the Blaze plan. AI assist runs the '
                      'client-side fallback classifier, geo-broadcast radius '
                      'expansion and candidate-lease expiry run client-side '
                      'timers instead of scheduled functions, and there is no '
                      'push notification delivery. See docs/RELEASE.md.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Collection health', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Document counts, to sanity-check that data is actually flowing.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<List<CollectionHealth>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AdminLoadingView();
              }
              if (snapshot.hasError) {
                return AdminErrorView(error: snapshot.error!, onRetry: _retry);
              }
              final items = snapshot.data!;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 200).floor().clamp(1, 6);
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: 2.2,
                    children: items.map((c) {
                      return Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.divider.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${c.count}', style: AppTextStyles.headlineSmall),
                            Text(
                              c.name,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BackendRow extends StatelessWidget {
  final String label;
  final bool deployed;
  final String note;
  const _BackendRow({required this.label, required this.deployed, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            deployed ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            color: deployed ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.titleSmall),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
