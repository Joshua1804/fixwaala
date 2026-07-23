import 'package:flutter/material.dart';

import '../core/models/enums.dart';
import '../core/models/user_model.dart';
import '../core/routes/route_names.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../features/auth/services/auth_service.dart';
import '../features/service_lifecycle/models/job_model.dart';
import '../features/service_lifecycle/services/job_service.dart';
import '../features/service_lifecycle/widgets/job_status_ui.dart';
import '../core/widgets/status_badge.dart';

/// Customer home screen with bottom navigation, gradient AppBar greeting,
/// service category grid, active ticket preview, and quick actions.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentTab = 0;

  late final AnimationController _entranceController;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
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
          _HomeTab(fadeAnimation: _fade),
          _TicketsTab(),
          _ProfileTab(),
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
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Tickets',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.of(context).pushNamed(RouteNames.createTicket),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}

// ── Home Tab ────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final Animation<double> fadeAnimation;
  const _HomeTab({required this.fadeAnimation});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Gradient AppBar ────────────────────────────────────
        SliverAppBar(
          expandedHeight: 160,
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
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
                                final name = snapshot.data?.name ?? 'there';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hi $name! 👋',
                                      style: AppTextStyles.headlineSmall
                                          .copyWith(color: Colors.white),
                                    ),
                                    Text(
                                      'What needs fixing today?',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Search bar ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: GestureDetector(
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.createTicket),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: AppColors.textHint,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Describe your problem...',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Section: Services ──────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text('Services', style: AppTextStyles.titleLarge),
            ),
          ),
        ),

        // ── Category grid ──────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: _CategoryGrid(),
            ),
          ),
        ),

        // ── Active ticket preview ──────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Tickets', style: AppTextStyles.titleLarge),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(RouteNames.myTickets),
                    child: const Text('See all'),
                  ),
                ],
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: const _ActiveTicketPreview(),
          ),
        ),

        // Bottom padding
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ── Category Grid ──────────────────────────────────────────────────
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  static const _tiles = [
    (
      'Plumbing',
      Icons.plumbing,
      AppColors.plumbing,
      [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    ),
    (
      'Electrical',
      Icons.electrical_services,
      AppColors.electrical,
      [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    ),
    (
      'Carpentry',
      Icons.chair_alt,
      AppColors.carpentry,
      [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    ),
    (
      'Other',
      Icons.handyman_rounded,
      AppColors.otherCat,
      [Color(0xFF6B7280), Color(0xFF9CA3AF)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: _tiles
          .map(
            (t) => _CategoryCard(
              label: t.$1,
              icon: t.$2,
              color: t.$3,
              gradientColors: t.$4,
              onTap: () =>
                  Navigator.of(context).pushNamed(RouteNames.createTicket),
            ),
          )
          .toList(),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: widget.gradientColors),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                style: AppTextStyles.labelLarge.copyWith(color: widget.color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Active Ticket Preview ──────────────────────────────────────────
/// Reflects the customer's real, currently in-flight job (if any). Tapping
/// it opens the live Job Tracking screen — this is the entry point back
/// into the Service Job Lifecycle flow after a provider has been confirmed.
class _ActiveTicketPreview extends StatelessWidget {
  const _ActiveTicketPreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, userSnapshot) {
          final customerId = userSnapshot.data?.id;
          if (customerId == null) return const SizedBox.shrink();

          return StreamBuilder<Job>(
            stream: JobService.instance.watchAllChanges(),
            builder: (context, _) {
              final job = JobService.instance.activeJobForCustomer(customerId);
              if (job == null) {
                return _NoActiveTicketCard(
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.createTicket),
                );
              }
              return _ActiveJobCard(job: job);
            },
          );
        },
      ),
    );
  }
}

class _NoActiveTicketCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NoActiveTicketCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.divider.withValues(alpha: 0.5),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.textHint.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.assignment_add,
                color: AppColors.textHint,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No active ticket', style: AppTextStyles.titleMedium),
                  Text(
                    'Tap to describe a problem and get matched',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

/// A live card for a real [Job], reused on the Home tab and Tickets tab.
class _ActiveJobCard extends StatelessWidget {
  final Job job;
  const _ActiveJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).pushNamed(RouteNames.jobTracking, arguments: job.jobId),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: JobStatusUi.color(job.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _categoryIcon(job.category),
                    color: JobStatusUi.color(job.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.providerName, style: AppTextStyles.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        _categoryLabel(job.category),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: JobStatusUi.label(job.status),
                  color: JobStatusUi.color(job.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: JobStatusUi.color(job.status).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    JobStatusUi.icon(job.status),
                    size: 16,
                    color: JobStatusUi.color(job.status),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      JobStatusUi.customerMessage(job.status),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: JobStatusUi.color(job.status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(ServiceCategory category) => switch (category) {
    ServiceCategory.plumber => Icons.plumbing,
    ServiceCategory.electrician => Icons.electrical_services,
    ServiceCategory.carpenter => Icons.chair_alt,
    ServiceCategory.unknown => Icons.handyman_rounded,
  };

  String _categoryLabel(ServiceCategory category) => switch (category) {
    ServiceCategory.plumber => 'Plumbing',
    ServiceCategory.electrician => 'Electrical',
    ServiceCategory.carpenter => 'Carpentry',
    ServiceCategory.unknown => 'Other',
  };
}

// ── Tickets tab ──────────────────────────────────────────────────────
class _TicketsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tickets')),
      body: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, userSnapshot) {
          final customerId = userSnapshot.data?.id;
          return StreamBuilder<Job>(
            stream: JobService.instance.watchAllChanges(),
            builder: (context, _) {
              final job = customerId == null
                  ? null
                  : JobService.instance.activeJobForCustomer(customerId);
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Active', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 12),
                  if (job != null)
                    _ActiveJobCard(job: job)
                  else
                    _NoActiveTicketCard(
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(RouteNames.createTicket),
                    ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('History', style: AppTextStyles.titleLarge),
                      TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushNamed(RouteNames.myTickets),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Past tickets and completed jobs appear here.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          final name = user?.name ?? 'Customer User';
          final phone = user?.phone ?? '98765 43210';
          final email = user?.email;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Profile header
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
                    Text(name, style: AppTextStyles.headlineSmall),
                    if (email != null && email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(email, style: AppTextStyles.bodyMedium),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '+91 $phone',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _ProfileTile(
                icon: Icons.history_rounded,
                label: 'Order History',
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.myTickets),
              ),
              _ProfileTile(
                icon: Icons.report_outlined,
                label: 'Report an Issue',
                onTap: () => Navigator.of(context).pushNamed(RouteNames.report),
              ),
              _ProfileTile(
                icon: Icons.help_outline_rounded,
                label: 'Help & Support',
                onTap: () {},
              ),
              _ProfileTile(
                icon: Icons.info_outline_rounded,
                label: 'About Fixwaala',
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _ProfileTile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                isDestructive: true,
                onTap: () => Navigator.of(
                  context,
                ).pushReplacementNamed(RouteNames.roleSelection),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfileTile({
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
      title: Text(label, style: AppTextStyles.bodyLarge.copyWith(color: color)),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textHint,
        size: 20,
      ),
    );
  }
}
