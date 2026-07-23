import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';
import '../../service_lifecycle/models/job_model.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../../service_lifecycle/widgets/job_status_ui.dart';

/// Admin's Active Tickets Screen — read-only view of every job's current
/// status, active and closed.
class ActiveTicketsScreen extends StatelessWidget {
  const ActiveTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tickets')),
      body: StreamBuilder<Job>(
        stream: JobService.instance.watchAllChanges(),
        builder: (context, _) {
          final jobs = JobService.instance.allJobs();
          if (jobs.isEmpty) {
            return Center(
              child: Text(
                'No tickets yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final job = jobs[i];
              return Card(
                child: ListTile(
                  title: Text('${job.customerName} → ${job.providerName}'),
                  subtitle: Text(job.jobId, style: AppTextStyles.caption),
                  trailing: StatusBadge(
                    label: JobStatusUi.label(job.status),
                    color: JobStatusUi.color(job.status),
                  ),
                  onTap: () => _showDetails(context, job),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetails(BuildContext context, Job job) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${job.customerName} → ${job.providerName}',
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('Status: ${JobStatusUi.label(job.status)}'),
            if (job.hasOpenReport)
              Text(
                '⚠ Has an open report',
                style: TextStyle(color: AppColors.warning),
              ),
            if (job.hasSafetyAlert)
              Text(
                '🚨 Has a safety alert',
                style: TextStyle(color: AppColors.error),
              ),
            const SizedBox(height: 12),
            Text('Created: ${job.createdAt}'),
            if (job.completedAt != null) Text('Completed: ${job.completedAt}'),
          ],
        ),
      ),
    );
  }
}
