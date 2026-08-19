import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/models/enums.dart';
import '../core/models/user_model.dart';
import '../core/routes/route_names.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/remote_image.dart';
import '../core/theme/app_durations.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/motion.dart';
import '../features/auth/services/auth_service.dart';
import '../features/geo_broadcast/services/geo_broadcast_service.dart';
import '../features/geo_broadcast/services/provider_presence_service.dart';
import '../features/geo_broadcast/widgets/incoming_requests_section.dart';
import '../features/provider_dashboard/models/analytics_model.dart';
import '../features/provider_dashboard/screens/provider_dashboard_screen.dart';
import '../features/provider_dashboard/services/analytics_service.dart';
import '../features/service_lifecycle/models/job_model.dart';
import '../features/service_lifecycle/screens/active_jobs_screen.dart';
import '../features/service_lifecycle/services/job_service.dart';
import '../features/customer_ticket/models/ticket_model.dart';
import '../features/trust_gated_matching/models/candidate_lease.dart';
import '../features/trust_gated_matching/services/matching_service.dart';
import '../core/widgets/floating_nav_bar.dart';
import '../core/widgets/status_badge.dart';
import '../core/widgets/profile/profile_settings_scaffold.dart';
import '../core/widgets/profile/profile_tile.dart';

/// Provider home screen with bottom navigation, gradient header with
/// earnings, online toggle with animation, quick stats, and opportunity cards.
class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentTab = 0;
  bool _online = false;
  String _providerId = AppConstants.demoProviderId;

  late final AnimationController _entranceController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: AppDurations.entrance,
    );
    _fade = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    if (prefersReducedMotion) {
      _entranceController.value = 1.0;
    } else {
      _entranceController.forward();
    }
    _loadOnlineStatus();
  }

  Future<void> _loadOnlineStatus() async {
    final user = await AuthService.instance.currentUser();
    if (!mounted) return;
    setState(() {
      _online = user?.providerProfile?.online ?? false;
      _providerId = user?.id ?? AppConstants.demoProviderId;
    });
  }

  Future<void> _handleToggleOnline(bool value) async {
    setState(() => _online = value);
    await ProviderPresenceService.instance.setOnline(value);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _CandidateOutcomeNotifier(
      providerId: _providerId,
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _currentTab,
          children: [
            _ProviderHomeTab(
              fadeAnimation: _fade,
              online: _online,
              onToggleOnline: _handleToggleOnline,
              providerId: _providerId,
              onViewAllRequests: () => setState(() => _currentTab = 1),
            ),
            ActiveJobsScreen(online: _online, providerId: _providerId),
            const ProviderDashboardScreen(),
            _ProviderProfileTab(),
          ],
        ),
        bottomNavigationBar: FloatingNavBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          items: const [
            FloatingNavBarItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
            ),
            FloatingNavBarItem(
              icon: Icons.work_outline_rounded,
              activeIcon: Icons.work_rounded,
              label: 'Jobs',
            ),
            FloatingNavBarItem(
              icon: Icons.bar_chart_outlined,
              activeIcon: Icons.bar_chart_rounded,
              label: 'Dashboard',
            ),
            FloatingNavBarItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Provider Home Tab ───────────────────────────────────────────────
class _ProviderHomeTab extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final bool online;
  final ValueChanged<bool> onToggleOnline;
  final String providerId;
  final VoidCallback onViewAllRequests;

  const _ProviderHomeTab({
    required this.fadeAnimation,
    required this.online,
    required this.onToggleOnline,
    required this.providerId,
    required this.onViewAllRequests,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Job>(
      stream: JobService.instance.watchAllChanges(),
      builder: (context, _) {
        return FutureBuilder<ProviderAnalytics>(
          future: AnalyticsService.instance.load(providerId),
          builder: (context, snapshot) {
            final analytics = snapshot.data ?? ProviderAnalytics.empty;
            return _buildScrollView(context, analytics);
          },
        );
      },
    );
  }

  Widget _buildScrollView(BuildContext context, ProviderAnalytics analytics) {
    return CustomScrollView(
      slivers: [
        // ── Gradient AppBar with earnings ──────────────────────
        SliverAppBar(
          expandedHeight: 180,
          floating: false,
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<AppUser?>(
                              stream: AuthService.instance.currentUserStream,
                              builder: (context, snapshot) {
                                final user = snapshot.data;
                                final name = user?.name ?? 'Provider';
                                return Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          14,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: user?.photoUrl != null
                                          ? RemoteImage(
                                              url: user!.photoUrl!,
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(
                                              Icons.person_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Hi $name! 👋',
                                            style: AppTextStyles.headlineSmall
                                                .copyWith(color: Colors.white),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              online
                                                  ? StatusBadge.online()
                                                  : StatusBadge.offline(),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          Semantics(
                            label: 'Notifications',
                            button: true,
                            child: IconButton(
                              onPressed: () => Navigator.of(
                                context,
                              ).pushNamed(RouteNames.notifications),
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Earnings row
                      GestureDetector(
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(RouteNames.providerEarnings),
                        child: Row(
                          children: [
                            Expanded(
                              child: _EarningsChip(
                                label: 'This month',
                                amount:
                                    '₹${analytics.earningsThisMonth.toStringAsFixed(0)}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _EarningsChip(
                                label: 'All time',
                                amount:
                                    '₹${analytics.earningsTotal.toStringAsFixed(0)}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Online toggle ─────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: _OnlineToggleCard(
                online: online,
                onChanged: onToggleOnline,
              ),
            ),
          ),
        ),

        // ── Quick stats ───────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(RouteNames.providerTrustScore),
                      child: _QuickStatCard(
                        icon: Icons.star_rounded,
                        value: analytics.ratingCount == 0
                            ? '—'
                            : analytics.ratingAverage.toStringAsFixed(1),
                        label: 'Rating',
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(RouteNames.providerActiveJobs),
                      child: _QuickStatCard(
                        icon: Icons.check_circle_rounded,
                        value: '${analytics.completedJobs}',
                        label: 'Jobs done',
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(RouteNames.providerPerformance),
                      child: _QuickStatCard(
                        icon: Icons.speed_rounded,
                        value: analytics.hasHistory
                            ? '${(analytics.completionRate * 100).toStringAsFixed(0)}%'
                            : '—',
                        label: 'Completion',
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Section: Available Opportunities ───────────────────
        if (online)
          FutureBuilder<AppUser?>(
            future: AuthService.instance.currentUser(),
            builder: (context, userSnap) {
              final user = userSnap.data;
              final categories =
                  user?.providerProfile?.skills ?? const <ServiceCategory>[];
              final location = user?.providerProfile?.liveLocation;

              // A provider with no skills selected receives nothing, and one
              // with no location cannot be matched to anything. Both used to
              // render `SizedBox.shrink()` — a blank gap with no explanation,
              // leaving the provider online, waiting, and wondering why no
              // jobs ever arrived.
              if (categories.isEmpty) {
                return const SliverToBoxAdapter(
                  child: ProviderDiagnostic(
                    icon: Icons.handyman_outlined,
                    title: 'No skills selected',
                    message:
                        'Add at least one skill so we know which jobs to send you.',
                  ),
                );
              }
              if (location == null) {
                return SliverToBoxAdapter(
                  child: ProviderDiagnostic(
                    icon: Icons.location_off_rounded,
                    title: 'Location unavailable',
                    message:
                        'We need your location to find jobs nearby. Check that '
                        'location permission is granted and try again.',
                    actionLabel: 'Enable location',
                    onAction: () =>
                        ProviderPresenceService.instance.updateLocationOnce(),
                  ),
                );
              }
              return StreamBuilder<List<Ticket>>(
                stream: GeoBroadcastService.instance.watchNearbyMatchingTickets(
                  categories: categories,
                  providerLocation: location,
                  providerId: user?.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint(
                      '[ProviderHome] watchNearbyMatchingTickets error: '
                      '${snapshot.error}',
                    );
                  }
                  final tickets = snapshot.data ?? [];
                  return _NewTicketNotifier(
                    tickets: tickets,
                    child: SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: fadeAnimation,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: IncomingRequestsSection(
                            tickets: tickets,
                            providerLocation: location,
                            error: snapshot.error,
                            limit: 3,
                            onViewAll: onViewAllRequests,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

        // ── Section: Quick Actions ────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text('Quick Actions', style: AppTextStyles.titleLarge),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _ActionCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Earnings summary',
                    subtitle: 'Breakdown of paid jobs',
                    color: AppColors.success,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(RouteNames.providerEarnings),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.verified_rounded,
                    title: 'Trust score',
                    subtitle: 'How customers see your reliability',
                    color: AppColors.primary,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(RouteNames.providerTrustScore),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Performance analytics',
                    subtitle: 'View your detailed stats',
                    color: AppColors.info,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(RouteNames.providerPerformance),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom padding — extra clearance for the floating nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ── Earnings Chip ──────────────────────────────────────────────────
class _EarningsChip extends StatelessWidget {
  final String label;
  final String amount;

  const _EarningsChip({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Online Toggle Card ─────────────────────────────────────────────
class _OnlineToggleCard extends StatelessWidget {
  final bool online;
  final ValueChanged<bool> onChanged;

  const _OnlineToggleCard({required this.online, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: online
            ? AppColors.success.withValues(alpha: 0.08)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: online
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.divider.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: online
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.textHint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              online
                  ? Icons.wifi_tethering_rounded
                  : Icons.wifi_tethering_off_rounded,
              color: online ? AppColors.success : AppColors.textHint,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? 'You are online' : 'You are offline',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: online ? AppColors.success : null,
                  ),
                ),
                Text(
                  online
                      ? 'Fixwaala can send you nearby jobs.'
                      : 'Toggle on to receive job opportunities.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: online, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Quick Stat Card ────────────────────────────────────────────────
class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _QuickStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.headlineMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Card ────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderProfileTab extends StatelessWidget {
  const _ProviderProfileTab();

  @override
  Widget build(BuildContext context) {
    return ProfileSettingsScaffold(
      fallbackName: 'Provider User',
      notificationsSubtitle: 'New job opportunities near you',
      // Granted by an administrator after manual review — never assumed.
      badgeBuilder: (user) => (user?.isVerified ?? false)
          ? StatusBadge.verified()
          : StatusBadge.pending(),
      tilesBuilder: (context, user) => [
        ProfileTile(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Earnings',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.providerEarnings),
        ),
        ProfileTile(
          icon: Icons.bar_chart_rounded,
          label: 'Performance',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.providerPerformance),
        ),
        ProfileTile(
          icon: Icons.trending_up_rounded,
          label: 'Trust score',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.providerTrustScore),
        ),
        ProfileTile(
          icon: Icons.handyman_rounded,
          label: 'Skills & availability',
          subtitle: 'Choose which jobs reach you',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.providerSkills),
        ),
        ProfileTile(
          icon: Icons.report_outlined,
          label: 'Report an Issue',
          onTap: () => Navigator.of(context).pushNamed(RouteNames.report),
        ),
        ProfileTile(
          icon: Icons.help_outline_rounded,
          label: 'Help & Support',
          onTap: () => Navigator.of(context).pushNamed(RouteNames.help),
        ),
      ],
    );
  }
}

class _NewTicketNotifier extends StatefulWidget {
  final List<Ticket> tickets;
  final Widget child;
  const _NewTicketNotifier({required this.tickets, required this.child});

  @override
  State<_NewTicketNotifier> createState() => _NewTicketNotifierState();
}

class _NewTicketNotifierState extends State<_NewTicketNotifier> {
  /// Ticket ids already announced, for the lifetime of the process.
  ///
  /// This was a per-instance field seeded in `initState`, so every remount —
  /// switching tabs, a rebuild of the parent — reset it and re-announced
  /// tickets the provider had already seen and in some cases already
  /// declined. Static state survives the widget; declines are excluded too.
  static final Set<String> _announcedIds = {};
  static bool _seeded = false;

  @override
  void didUpdateWidget(_NewTicketNotifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkForNewTickets();
  }

  @override
  void initState() {
    super.initState();
    if (!_seeded) {
      // Whatever is already on screen at first mount is not "new".
      _announcedIds.addAll(widget.tickets.map((t) => t.id));
      _seeded = true;
    }
    _checkForNewTickets();
  }

  void _checkForNewTickets() {
    for (final ticket in widget.tickets) {
      if (_announcedIds.contains(ticket.id)) continue;
      _announcedIds.add(ticket.id);
      NotificationService.instance.showLocalAlert(
        title: 'New service request nearby',
        body: ticket.description,
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Tells a provider when a customer confirmed someone else for a ticket
/// they'd accepted. Mounted once at the screen root so it fires regardless
/// of which tab is open — a provider who loses out on the Jobs tab still
/// needs to know.
///
/// `watchMyOutcomes` only reports leases currently sitting at
/// `notSelected`, so the first emission is whatever already happened before
/// this session; seeding it as "already announced" (same shape as
/// [_NewTicketNotifier]) stops every app restart from re-surfacing every
/// loss a provider has ever taken.
class _CandidateOutcomeNotifier extends StatefulWidget {
  final String providerId;
  final Widget child;
  const _CandidateOutcomeNotifier({
    required this.providerId,
    required this.child,
  });

  @override
  State<_CandidateOutcomeNotifier> createState() =>
      _CandidateOutcomeNotifierState();
}

class _CandidateOutcomeNotifierState extends State<_CandidateOutcomeNotifier> {
  static final Set<String> _announcedTicketIds = {};
  static bool _seeded = false;

  StreamSubscription<List<CandidateLease>>? _sub;
  String? _watchingProviderId;

  @override
  void initState() {
    super.initState();
    _resubscribe();
  }

  @override
  void didUpdateWidget(_CandidateOutcomeNotifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerId != widget.providerId) _resubscribe();
  }

  void _resubscribe() {
    _sub?.cancel();
    _watchingProviderId = widget.providerId;
    _sub = MatchingService.instance
        .watchMyOutcomes(widget.providerId)
        .listen(_check);
  }

  void _check(List<CandidateLease> outcomes) {
    // A stale subscription's late emission arriving after the provider id
    // changed would otherwise announce (or seed) under the wrong identity.
    if (widget.providerId != _watchingProviderId) return;
    if (!_seeded) {
      _announcedTicketIds.addAll(outcomes.map((o) => o.ticketId));
      _seeded = true;
      return;
    }
    for (final outcome in outcomes) {
      if (_announcedTicketIds.contains(outcome.ticketId)) continue;
      _announcedTicketIds.add(outcome.ticketId);
      NotificationService.instance.showLocalAlert(
        title: 'Request no longer available',
        body:
            'The customer chose another provider for the '
            '${outcome.category.name} job.',
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
