import 'package:flutter/material.dart';

import '../core/models/user_model.dart';
import '../core/routes/route_names.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../features/auth/services/auth_service.dart';
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
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: [
          _ProviderHomeTab(
            fadeAnimation: _fade,
            online: _online,
            onToggleOnline: (v) => setState(() => _online = v),
          ),
          _JobsTab(),
          _DashboardTab(),
          _ProviderProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) => setState(() => _currentTab = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work_outline_rounded),
              activeIcon: Icon(Icons.work_rounded),
              label: 'Jobs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
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

  const _ProviderHomeTab({
    required this.fadeAnimation,
    required this.online,
    required this.onToggleOnline,
  });

  @override
  Widget build(BuildContext context) {
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
                                      style: AppTextStyles.headlineSmall.copyWith(
                                        color: Colors.white,
                                      ),
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
                      Row(
                        children: [
                          _EarningsChip(
                            label: 'Today',
                            amount: '₹1,250',
                          ),
                          const SizedBox(width: 12),
                          _EarningsChip(
                            label: 'This week',
                            amount: '₹8,400',
                          ),
                        ],
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
                children: const [
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.star_rounded,
                      value: '4.8',
                      label: 'Rating',
                      color: AppColors.accent,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.check_circle_rounded,
                      value: '132',
                      label: 'Jobs done',
                      color: AppColors.success,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.speed_rounded,
                      value: '95%',
                      label: 'Completion',
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Section: Opportunities ────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Quick Actions',
                style: AppTextStyles.titleLarge,
              ),
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
                    icon: Icons.notifications_active_rounded,
                    title: 'Simulate incoming opportunity',
                    subtitle: 'Test the job matching flow',
                    color: AppColors.accent,
                    onTap: () => Navigator.of(context)
                        .pushNamed(RouteNames.providerOpportunity),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.verified_user_rounded,
                    title: 'Verification status',
                    subtitle: 'Check your identity verification',
                    color: AppColors.success,
                    onTap: () => Navigator.of(context)
                        .pushNamed(RouteNames.verificationStatus),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Performance analytics',
                    subtitle: 'View your detailed stats',
                    color: AppColors.info,
                    onTap: () => Navigator.of(context)
                        .pushNamed(RouteNames.providerPerformance),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
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

  const _OnlineToggleCard({
    required this.online,
    required this.onChanged,
  });

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
          Switch(
            value: online,
            onChanged: onChanged,
          ),
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
        border: Border.all(
          color: color.withValues(alpha: 0.12),
        ),
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
            border: Border.all(
              color: AppColors.divider.withValues(alpha: 0.5),
            ),
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
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Placeholder tabs ────────────────────────────────────────────────
class _JobsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Jobs')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_off_rounded,
                size: 64,
                color: AppColors.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No active jobs',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go online to start receiving jobs',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 64,
                color: AppColors.textHint.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Analytics coming soon',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final name = user?.name ?? 'Provider User';
          final phone = user?.phone ?? '98765 43210';
          final email = user?.email;

          return ListView(
            padding: const EdgeInsets.all(20),
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
                      child: const Icon(Icons.person_rounded,
                          size: 36, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(name, style: AppTextStyles.headlineSmall),
                    if (email != null && email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(email, style: AppTextStyles.bodyMedium),
                    ],
                    const SizedBox(height: 4),
                    StatusBadge.verified(),
                    const SizedBox(height: 4),
                    Text('+91 $phone',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _ProviderProfileTile(
                icon: Icons.verified_user_rounded,
                label: 'Verification',
                onTap: () => Navigator.of(context)
                    .pushNamed(RouteNames.verificationStatus),
              ),
              _ProviderProfileTile(
                icon: Icons.bar_chart_rounded,
                label: 'Performance',
                onTap: () => Navigator.of(context)
                    .pushNamed(RouteNames.providerPerformance),
              ),
              _ProviderProfileTile(
                icon: Icons.report_outlined,
                label: 'Report an Issue',
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.report),
              ),
              _ProviderProfileTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _ProviderProfileTile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                isDestructive: true,
                onTap: () => Navigator.of(context)
                    .pushReplacementNamed(RouteNames.roleSelection),
              ),
            ],
          );
        },
      ),
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
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
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
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: AppTextStyles.bodyLarge.copyWith(color: color),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint, size: 20),
    );
  }
}
