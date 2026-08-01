import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/services/auth_service.dart';
import '../../payment/services/payment_service.dart';
import '../../service_lifecycle/models/job_model.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/analytics_model.dart';
import '../services/analytics_service.dart';

/// Earnings Summary Screen — breakdown of a provider's completed-job
/// earnings, separate from performance trends.
class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings summary')),
      body: FutureBuilder(
        future: AuthService.instance.currentUser(),
        builder: (context, userSnap) {
          final providerId = userSnap.data?.id ?? AppConstants.demoProviderId;
          return StreamBuilder<Job>(
            stream: JobService.instance.watchAllChanges(),
            builder: (context, _) => _buildBody(context, providerId),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, String providerId) {
    return FutureBuilder<ProviderAnalytics>(
      future: AnalyticsService.instance.load(providerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingWidget(label: 'Loading earnings...');
        }
        final a = snapshot.data ?? ProviderAnalytics.empty;
        if (!a.hasHistory) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 64,
                    color: AppColors.textHint.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No earnings yet',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final completedJobs = JobService.instance.completedJobsForProvider(
          providerId,
        );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This month',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${a.earningsThisMonth.toStringAsFixed(0)}',
                    style: AppTextStyles.displayMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'All-time total: ₹${a.earningsTotal.toStringAsFixed(0)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Paid jobs', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            for (final job in completedJobs)
              Builder(
                builder: (context) {
                  final payment = PaymentService.instance.paymentForJob(
                    job.jobId,
                  );
                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.receipt_rounded,
                        color: AppColors.success,
                      ),
                      title: Text(job.customerName),
                      subtitle: Text(
                        job.completedAt
                                ?.toLocal()
                                .toString()
                                .split('.')
                                .first ??
                            '',
                      ),
                      trailing: Text(
                        payment == null
                            ? 'Unpaid'
                            : '₹${payment.amount.toStringAsFixed(0)}',
                        style: AppTextStyles.titleMedium,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
