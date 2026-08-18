import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/services/auth_service.dart';
import '../../customer_ticket/models/ticket_model.dart';
import '../../geo_broadcast/services/geo_broadcast_service.dart';
import '../../geo_broadcast/services/provider_presence_service.dart';
import '../../geo_broadcast/widgets/incoming_requests_section.dart';
import '../models/job_model.dart';
import '../services/job_service.dart';
import '../widgets/job_status_ui.dart';

/// Provider's Jobs Screen — Incoming / Active / History, kept visually and
/// navigationally distinct.
///
/// `online` and `providerId` are supplied live by [ProviderHomeScreen] when
/// this is embedded as a bottom-nav tab (kept alive by an `IndexedStack`, so
/// they must stay reactive rather than being fetched once). The standalone
/// `RouteNames.providerActiveJobs` push in `app_router.dart` has neither
/// available, so both are optional and fall back to a self-fetch.
class ActiveJobsScreen extends StatefulWidget {
  final bool? online;
  final String? providerId;
  const ActiveJobsScreen({super.key, this.online, this.providerId});

  @override
  State<ActiveJobsScreen> createState() => _ActiveJobsScreenState();
}

class _ActiveJobsScreenState extends State<ActiveJobsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _providerId;
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _providerId = widget.providerId;
    _online = widget.online ?? false;
    if (widget.providerId == null) {
      _loadProviderContext();
    }
  }

  @override
  void didUpdateWidget(ActiveJobsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.online != null && widget.online != oldWidget.online) {
      setState(() => _online = widget.online!);
    }
    // [ProviderHomeScreen] starts this tab with a placeholder id
    // (`AppConstants.demoProviderId`) and swaps in the real signed-in uid
    // once `currentUser()` resolves. That update reaches this screen as a
    // new `widget.providerId`, but `_providerId` was only ever copied from
    // it in `initState`, so without this it stayed pinned to the
    // placeholder for the rest of the session — Active and History (which
    // filter jobs by exact provider id) stayed empty even though jobs
    // existed, while Incoming kept working because it doesn't filter on it.
    if (widget.providerId != null && widget.providerId != oldWidget.providerId) {
      setState(() => _providerId = widget.providerId);
    }
  }

  Future<void> _loadProviderContext() async {
    final user = await AuthService.instance.currentUser();
    if (!mounted) return;
    setState(() {
      _providerId = user?.id ?? AppConstants.demoProviderId;
      _online = user?.providerProfile?.online ?? false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerId = _providerId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Jobs'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Incoming'),
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: providerId == null
          ? const LoadingWidget(label: 'Loading your jobs...')
          : StreamBuilder<Job>(
              // Re-render whenever any job changes.
              stream: JobService.instance.watchAllChanges(),
              builder: (context, _) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _IncomingTab(online: _online, providerId: providerId),
                    _JobList(
                      jobs: JobService.instance.activeJobsForProvider(
                        providerId,
                      ),
                      emptyIcon: Icons.work_off_rounded,
                      emptyTitle: 'No active jobs',
                      emptySubtitle: 'Go online to start receiving jobs.',
                    ),
                    _JobList(
                      jobs: JobService.instance.historyJobsForProvider(
                        providerId,
                      ),
                      emptyIcon: Icons.checklist_rounded,
                      emptyTitle: 'No job history yet',
                      emptySubtitle:
                          'Finished and cancelled jobs show up here.',
                    ),
                  ],
                );
              },
            ),
    );
  }
}

/// The full, uncapped incoming-requests feed — the preview on the provider
/// home screen caps this at 3 and links here for the rest.
class _IncomingTab extends StatelessWidget {
  final bool online;
  final String providerId;
  const _IncomingTab({required this.online, required this.providerId});

  @override
  Widget build(BuildContext context) {
    if (!online) {
      return const _IncomingDiagnostic(
        icon: Icons.wifi_off_rounded,
        title: "You're offline",
        message: 'Go online from Home to start receiving nearby requests.',
      );
    }
    return FutureBuilder<AppUser?>(
      future: AuthService.instance.currentUser(),
      builder: (context, userSnap) {
        final user = userSnap.data;
        final categories =
            user?.providerProfile?.skills ?? const <ServiceCategory>[];
        final location = user?.providerProfile?.liveLocation;

        if (categories.isEmpty) {
          return const _IncomingDiagnostic(
            icon: Icons.handyman_outlined,
            title: 'No skills selected',
            message:
                'Add at least one skill so we know which jobs to send you.',
          );
        }
        if (location == null) {
          return _IncomingDiagnostic(
            icon: Icons.location_off_rounded,
            title: 'Location unavailable',
            message:
                'We need your location to find jobs nearby. Check that '
                'location permission is granted and try again.',
            actionLabel: 'Enable location',
            onAction: () =>
                ProviderPresenceService.instance.updateLocationOnce(),
          );
        }
        return StreamBuilder<List<Ticket>>(
          stream: GeoBroadcastService.instance.watchNearbyMatchingTickets(
            categories: categories,
            providerLocation: location,
            providerId: providerId,
          ),
          builder: (context, snapshot) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: IncomingRequestsSection(
                tickets: snapshot.data ?? [],
                providerLocation: location,
                error: snapshot.error,
              ),
            );
          },
        );
      },
    );
  }
}

class _IncomingDiagnostic extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _IncomingDiagnostic({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ProviderDiagnostic(
        icon: icon,
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
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
      separatorBuilder: (_, _) => const SizedBox(height: 12),
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
