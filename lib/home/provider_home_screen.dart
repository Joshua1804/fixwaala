import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/models/enums.dart';
import '../core/models/user_model.dart';
import '../core/routes/route_names.dart';
import '../core/services/location_service.dart';
import '../core/services/notification_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_durations.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/motion.dart';
import '../features/auth/services/auth_service.dart';
import '../features/geo_broadcast/services/geo_broadcast_service.dart';
import '../features/geo_broadcast/services/provider_presence_service.dart';
import '../features/provider_dashboard/models/analytics_model.dart';
import '../features/provider_dashboard/screens/provider_dashboard_screen.dart';
import '../features/provider_dashboard/services/analytics_service.dart';
import '../features/service_lifecycle/models/job_model.dart';
import '../features/service_lifecycle/screens/active_jobs_screen.dart';
import '../features/service_lifecycle/services/job_service.dart';
import '../features/customer_ticket/models/ticket_model.dart';
import '../features/trust_gated_matching/services/matching_service.dart';
import '../core/services/app_preferences_service.dart';
import '../core/widgets/custom_button.dart';
import '../core/widgets/floating_nav_bar.dart';
import '../core/widgets/status_badge.dart';

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
    setState(() => _online = user?.providerProfile?.online ?? false);
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
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentTab,
        children: [
          _ProviderHomeTab(
            fadeAnimation: _fade,
            online: _online,
            onToggleOnline: _handleToggleOnline,
          ),
          const ActiveJobsScreen(),
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
    );
  }
}

// ── Provider Home Tab ───────────────────────────────────────────────
class _ProviderHomeTab extends StatelessWidget {
  final Animation<double> fadeAnimation;
  final bool online;
  final ValueChanged<bool> onToggleOnline;

  const _ProviderHomeTab({
    required this.fadeAnimation,
    required this.online,
    required this.onToggleOnline,
  });

  // NOTE: uses a shared demo provider id — see AppConstants.demoProviderId.
  String get _providerId => AppConstants.demoProviderId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Job>(
      stream: JobService.instance.watchAllChanges(),
      builder: (context, _) {
        return FutureBuilder<ProviderAnalytics>(
          future: AnalyticsService.instance.load(_providerId),
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
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FutureBuilder<AppUser?>(
                              future: AuthService.instance.currentUser(),
                              builder: (context, snapshot) {
                                final name = snapshot.data?.name ?? 'Provider';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                );
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(
                              Icons.notifications_outlined,
                              color: Colors.white.withValues(alpha: 0.8),
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
                            _EarningsChip(
                              label: 'This month',
                              amount:
                                  '₹${analytics.earningsThisMonth.toStringAsFixed(0)}',
                            ),
                            const SizedBox(width: 12),
                            _EarningsChip(
                              label: 'All time',
                              amount:
                                  '₹${analytics.earningsTotal.toStringAsFixed(0)}',
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
              if (location == null) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return StreamBuilder<List<Ticket>>(
                stream: GeoBroadcastService.instance.watchNearbyMatchingTickets(
                  categories: categories,
                  providerLocation: location,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Incoming Service Requests',
                                    style: AppTextStyles.titleLarge,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${tickets.length} LIVE',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (snapshot.hasError)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.error.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: AppColors.error,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Could not load requests: '
                                          '${snapshot.error}',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(color: AppColors.error),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (tickets.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardTheme.color,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.divider.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.search_rounded,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Waiting for customer requests nearby...',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...tickets.map(
                                  (ticket) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _OpportunityTicketCard(
                                      ticket: ticket,
                                      distanceKm: LocationService.instance
                                          .distanceKm(
                                            location,
                                            ticket.approximateLocation,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
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
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.verified_user_rounded,
                    title: 'Verification status',
                    subtitle: 'Check your identity verification',
                    color: AppColors.textSecondary,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(RouteNames.verificationStatus),
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

class _ProviderProfileTab extends StatefulWidget {
  const _ProviderProfileTab();

  @override
  State<_ProviderProfileTab> createState() => _ProviderProfileTabState();
}

class _ProviderProfileTabState extends State<_ProviderProfileTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;

          if (user != null) {
            _nameController.text = user.name ?? '';
            _phoneController.text = user.phone ?? '';
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _ProviderProfileContent(
                user: user,
                nameController: _nameController,
                phoneController: _phoneController,
              ),
              _ProviderSettingsContent(user: user),
            ],
          );
        },
      ),
    );
  }
}

class _ProviderProfileContent extends StatefulWidget {
  final AppUser? user;
  final TextEditingController nameController;
  final TextEditingController phoneController;

  const _ProviderProfileContent({
    required this.user,
    required this.nameController,
    required this.phoneController,
  });

  @override
  State<_ProviderProfileContent> createState() =>
      _ProviderProfileContentState();
}

class _ProviderProfileContentState extends State<_ProviderProfileContent> {
  bool _isEditing = false;

  void _handleSave() {
    if (widget.user != null) {
      widget.user!.copyWith(
        name: widget.nameController.text,
        phone: widget.phoneController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          duration: Duration(seconds: 2),
        ),
      );

      setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.user?.name ?? 'Provider User',
                style: AppTextStyles.headlineSmall,
              ),
              if (widget.user?.email.isNotEmpty ?? false) ...[
                const SizedBox(height: 2),
                Text(widget.user!.email, style: AppTextStyles.bodyMedium),
              ],
              const SizedBox(height: 4),
              StatusBadge.verified(),
              if (widget.user?.phone?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  '+91 ${widget.user!.phone}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Basic Information', style: AppTextStyles.titleLarge),
            TextButton(
              onPressed: () => setState(() => _isEditing = !_isEditing),
              child: Text(_isEditing ? 'Cancel' : 'Edit'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildEditableField(
          label: 'Name',
          controller: widget.nameController,
          enabled: _isEditing,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildEditableField(
          label: 'Phone',
          controller: widget.phoneController,
          enabled: _isEditing,
          keyboardType: TextInputType.phone,
          isDark: isDark,
        ),
        if (_isEditing) ...[
          const SizedBox(height: 20),
          PrimaryButton(label: 'Save Changes', onPressed: _handleSave),
        ],
        const SizedBox(height: 32),
        _ProviderProfileTile(
          icon: Icons.verified_user_rounded,
          label: 'Verification',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.verificationStatus),
        ),
        _ProviderProfileTile(
          icon: Icons.account_balance_wallet_rounded,
          label: 'Earnings',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.providerEarnings),
        ),
        _ProviderProfileTile(
          icon: Icons.bar_chart_rounded,
          label: 'Performance',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.providerPerformance),
        ),
        _ProviderProfileTile(
          icon: Icons.verified_rounded,
          label: 'Trust score',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.providerTrustScore),
        ),
        _ProviderProfileTile(
          icon: Icons.report_outlined,
          label: 'Report an Issue',
          onTap: () => Navigator.of(context).pushNamed(RouteNames.report),
        ),
        _ProviderProfileTile(
          icon: Icons.help_outline_rounded,
          label: 'Help & Support',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? (isDark ? AppColors.cardDark : AppColors.surface)
                : AppColors.textHint.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.textHint.withValues(alpha: 0.1),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            hintText: label,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textHint,
            ),
          ),
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }
}

class _ProviderSettingsContent extends StatelessWidget {
  final AppUser? user;

  const _ProviderSettingsContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: [
        Text('App Preferences', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        _ProviderSettingsSection(
          child: StreamBuilder<ThemeMode>(
            stream: AppPreferencesService.instance.themeModeStream,
            initialData: AppPreferencesService.instance.themeMode,
            builder: (context, snapshot) {
              final currentMode = snapshot.data ?? ThemeMode.system;
              return Column(
                children: [
                  _buildThemeOption(
                    context,
                    'Light',
                    ThemeMode.light,
                    Icons.light_mode_rounded,
                    currentMode == ThemeMode.light,
                  ),
                  const SizedBox(height: 12),
                  _buildThemeOption(
                    context,
                    'Dark',
                    ThemeMode.dark,
                    Icons.dark_mode_rounded,
                    currentMode == ThemeMode.dark,
                  ),
                  const SizedBox(height: 12),
                  _buildThemeOption(
                    context,
                    'System',
                    ThemeMode.system,
                    Icons.brightness_auto_rounded,
                    currentMode == ThemeMode.system,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text('Notifications', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        _ProviderSettingsSection(
          child: StreamBuilder<bool>(
            stream: AppPreferencesService.instance.notificationsEnabledStream,
            initialData: AppPreferencesService.instance.notificationsEnabled,
            builder: (context, snapshot) {
              final enabled = snapshot.data ?? true;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enable notifications',
                        style: AppTextStyles.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Job requests and updates',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (value) => AppPreferencesService.instance
                        .setNotificationsEnabled(value),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text('Account', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        _ProviderProfileTile(
          icon: Icons.lock_outline_rounded,
          label: 'Change Password',
          onTap: () {},
        ),
        _ProviderProfileTile(
          icon: Icons.verified_user_outlined,
          label: 'Email Verification Status',
          onTap: () {},
        ),
        const SizedBox(height: 24),
        Text('About', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        _ProviderProfileTile(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          onTap: () {},
        ),
        _ProviderProfileTile(
          icon: Icons.description_outlined,
          label: 'Terms of Service',
          onTap: () {},
        ),
        _ProviderProfileTile(
          icon: Icons.info_outline_rounded,
          label: 'Version Info',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Fixwaala'),
                content: const Text('Version 1.0.0\n\nBuild: 1'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        _ProviderProfileTile(
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          isDestructive: true,
          onTap: () => Navigator.of(
            context,
          ).pushReplacementNamed(RouteNames.roleSelection),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String label,
    ThemeMode mode,
    IconData icon,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () => AppPreferencesService.instance.setThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.bodyLarge.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _ProviderSettingsSection extends StatelessWidget {
  final Widget child;

  const _ProviderSettingsSection({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.glassBorderDark
              : AppColors.divider.withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}

class _ProviderProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProviderProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final color = isDestructive
        ? AppColors.error
        : (isDark ? Colors.white : AppColors.textPrimary);

    final iconColor = isDestructive ? AppColors.error : AppColors.primary;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (isDestructive ? AppColors.error : AppColors.primary)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label, style: AppTextStyles.bodyLarge.copyWith(color: color)),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textHint,
        size: 20,
      ),
    );
  }
}

// ── Opportunity Ticket Card ────────────────────────────────────────
/// Fires a local notification for every ticket that appears in [tickets]
/// which wasn't there before — the in-app stand-in for a push notification
/// when a new nearby request comes in (there is no push backend).
class _NewTicketNotifier extends StatefulWidget {
  final List<Ticket> tickets;
  final Widget child;
  const _NewTicketNotifier({required this.tickets, required this.child});

  @override
  State<_NewTicketNotifier> createState() => _NewTicketNotifierState();
}

class _NewTicketNotifierState extends State<_NewTicketNotifier> {
  Set<String> _seenIds = {};
  bool _initialized = false;

  @override
  void didUpdateWidget(_NewTicketNotifier oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkForNewTickets();
  }

  @override
  void initState() {
    super.initState();
    _seenIds = widget.tickets.map((t) => t.id).toSet();
    _initialized = true;
  }

  void _checkForNewTickets() {
    if (!_initialized) return;
    final newTickets = widget.tickets.where((t) => !_seenIds.contains(t.id));
    for (final ticket in newTickets) {
      NotificationService.instance.showLocalAlert(
        title: 'New service request nearby',
        body: ticket.description,
      );
    }
    _seenIds = widget.tickets.map((t) => t.id).toSet();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _OpportunityTicketCard extends StatefulWidget {
  final Ticket ticket;
  final double distanceKm;
  const _OpportunityTicketCard({
    required this.ticket,
    required this.distanceKm,
  });

  @override
  State<_OpportunityTicketCard> createState() => _OpportunityTicketCardState();
}

class _OpportunityTicketCardState extends State<_OpportunityTicketCard> {
  bool _accepting = false;
  bool _declined = false;

  Future<void> _accept(AppUser? currentProvider) async {
    setState(() => _accepting = true);
    try {
      final providerId = currentProvider?.id ?? AppConstants.demoProviderId;

      await MatchingService.instance.acceptOpportunity(
        ticketId: widget.ticket.id,
        providerId: providerId,
        provider: currentProvider,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accepted — waiting for the customer to confirm.'),
          backgroundColor: AppColors.success,
        ),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _decline(AppUser? currentProvider) async {
    final providerId = currentProvider?.id ?? AppConstants.demoProviderId;
    await MatchingService.instance.declineOpportunity(
      ticketId: widget.ticket.id,
      providerId: providerId,
    );
    if (!mounted) return;
    setState(() => _declined = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_declined) return const SizedBox.shrink();
    return FutureBuilder<AppUser?>(
      future: AuthService.instance.currentUser(),
      builder: (context, userSnap) {
        final currentProvider = userSnap.data;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.ticket.category.name.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.ticket.createdAt.hour.toString().padLeft(2, '0')}:${widget.ticket.createdAt.minute.toString().padLeft(2, '0')}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Customer: ${widget.ticket.customerName}',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.ticket.description,
                style: AppTextStyles.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.route_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.distanceKm.toStringAsFixed(1)} km away · '
                    '~${(widget.distanceKm * 2).round().clamp(1, 999)} min',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _accepting
                          ? null
                          : () => _decline(currentProvider),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _accepting
                          ? null
                          : () => _accept(currentProvider),
                      icon: _accepting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
