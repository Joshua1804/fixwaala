import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/job_model.dart';
import '../services/job_service.dart';
import '../widgets/job_status_ui.dart';

/// Provider's Active Jobs Screen — separate Active / Completed sections,
/// per the requirement to keep those visually and navigationally distinct.
class ActiveJobsScreen extends StatefulWidget {
  const ActiveJobsScreen({super.key});

  @override
  State<ActiveJobsScreen> createState() => _ActiveJobsScreenState();
}

class _ActiveJobsScreenState extends State<ActiveJobsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // NOTE: uses a shared demo provider id — see AppConstants.demoProviderId.
  String get _providerId => AppConstants.demoProviderId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Jobs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: StreamBuilder<Job>(
        // Re-render whenever any job changes.
        stream: JobService.instance.watchAllChanges(),
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _JobList(
                jobs: JobService.instance.activeJobsForProvider(_providerId),
                emptyIcon: Icons.work_off_rounded,
                emptyTitle: 'No active jobs',
                emptySubtitle: 'Go online to start receiving jobs.',
              ),
              _JobList(
                jobs: JobService.instance.historyJobsForProvider(_providerId),
                emptyIcon: Icons.checklist_rounded,
                emptyTitle: 'No job history yet',
                emptySubtitle: 'Finished and cancelled jobs show up here.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  final List<Job> jobs;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  const _JobList({
    required this.jobs,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return EmptyStateWidget(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _JobCard(job: jobs[i]),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(
          context,
        ).pushNamed(RouteNames.providerJobDetails, arguments: job.jobId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: JobStatusUi.color(job.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ServiceCategoryUi.icon(job.category),
                  color: JobStatusUi.color(job.status),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.customerName, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      ServiceCategoryUi.label(job.category),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(
                    label: JobStatusUi.label(job.status),
                    color: JobStatusUi.color(job.status),
                  ),
                  if (job.hasSafetyAlert) ...[
                    const SizedBox(height: 4),
                    StatusBadge.error('SOS', icon: Icons.emergency),
                  ] else if (job.hasOpenReport) ...[
                    const SizedBox(height: 4),
                    StatusBadge.warning('Reported'),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
