import 'package:flutter/material.dart';

import '../core/models/enums.dart';
import '../core/models/user_model.dart';
import '../core/routes/route_names.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_durations.dart';
import '../core/theme/app_radii.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/motion.dart';
import '../features/auth/services/auth_service.dart';
import '../features/customer_ticket/models/ticket_model.dart';
import '../features/customer_ticket/services/ticket_service.dart';
import '../features/customer_ticket/widgets/ticket_status_ui.dart';
import '../features/service_lifecycle/models/job_model.dart';
import '../features/service_lifecycle/services/job_service.dart';
import '../features/service_lifecycle/widgets/job_status_ui.dart';
import '../core/services/app_preferences_service.dart';
import '../core/widgets/custom_button.dart';
import '../core/widgets/empty_state_widget.dart';
import '../core/widgets/floating_nav_bar.dart';
import '../core/widgets/hero_banner.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/offer_card.dart';
import '../core/widgets/popular_service_card.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/service_category_tile.dart';
import '../core/widgets/service_category_ui.dart';
import '../core/widgets/status_badge.dart';
import '../core/widgets/trust_point_tile.dart';

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
      duration: AppDurations.entrance,
    );
    _fade = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    if (prefersReducedMotion) {
      _entranceController.value = 1.0;
    } else {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  static const double _wideBreakpoint = 900;

  void _selectTab(int i) => setState(() => _currentTab = i);

  @override
  Widget build(BuildContext context) {
    final tabs = [_HomeTab(fadeAnimation: _fade), _TicketsTab(), _ProfileTab()];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        return Scaffold(
          extendBody: true,
          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  selectedIndex: _currentTab,
                  onDestinationSelected: _selectTab,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: AppColors.surface,
                  selectedIconTheme: const IconThemeData(
                    color: AppColors.primary,
                  ),
                  unselectedIconTheme: IconThemeData(color: AppColors.textHint),
                  selectedLabelTextStyle: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelTextStyle: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textHint,
                  ),
                  leading: const SizedBox(height: 12),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Tickets'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: Text('Profile'),
                    ),
                  ],
                ),
              if (isWide)
                const VerticalDivider(width: 1, color: AppColors.divider),
              Expanded(
                child: IndexedStack(index: _currentTab, children: tabs),
              ),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : FloatingNavBar(
                  currentIndex: _currentTab,
                  onTap: _selectTab,
                  items: const [
                    FloatingNavBarItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                    ),
                    FloatingNavBarItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'Tickets',
                    ),
                    FloatingNavBarItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile',
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(RouteNames.createTicket),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        );
      },
    );
  }
}

/// The 4 real [ServiceCategory] values shown on the home grid, mapped
/// through [ServiceCategoryUi] for icon/label. Combined with
/// [kCosmeticOnlyCategoryTiles] to make up the brief's 6-tile grid.
const _realHomeCategories = [
  ServiceCategory.plumber,
  ServiceCategory.electrician,
  ServiceCategory.carpenter,
  ServiceCategory.unknown,
];

const _popularServices = [
  (
    icon: Icons.hvac_rounded,
    title: 'AC Repair & Service',
    description: 'Diagnose, repair, or service any AC unit',
    price: 'From ₹399',
    rating: 4.7,
  ),
  (
    icon: Icons.plumbing,
    title: 'Pipe Leak Fix',
    description: 'Quick fixes for leaks and clogged pipes',
    price: 'From ₹249',
    rating: 4.8,
  ),
  (
    icon: Icons.electrical_services,
    title: 'Switchboard & Wiring',
    description: 'Safe electrical repairs by certified pros',
    price: 'From ₹299',
    rating: 4.6,
  ),
  (
    icon: Icons.chair_alt,
    title: 'Furniture Repair',
    description: 'Fix wobbly chairs, doors, and cabinets',
    price: 'From ₹349',
    rating: 4.5,
  ),
  (
    icon: Icons.cleaning_services_rounded,
    title: 'Deep Home Cleaning',
    description: 'Thorough cleaning for kitchens and bathrooms',
    price: 'From ₹599',
    rating: 4.9,
  ),
];

// ── Home Tab ────────────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final Animation<double> fadeAnimation;
  const _HomeTab({required this.fadeAnimation});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

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
                          Semantics(
                            label: 'Notifications',
                            button: true,
                            child: IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Icons.notifications_outlined,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
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
              child: Semantics(
                label:
                    'Search for a service, e.g. Plumber, Electrician, AC repair',
                button: true,
                child: GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushNamed(RouteNames.createTicket),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadii.input),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: AppShadows.subtle,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: AppColors.secondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search "Plumber", "Electrician", "AC repair"…',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
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
        ),

        // ── Hero banner ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: HeroBanner(
                headline: 'Reliable help for every home repair',
                subheadline:
                    'Verified professionals, transparent pricing, and safe bookings.',
                ctaLabel: 'Request a repair',
                onCtaTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.createTicket),
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
              child: const SectionHeader(title: 'Services'),
            ),
          ),
        ),

        // ── Category grid ──────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _CategoryGrid(isWide: isWide),
            ),
          ),
        ),

        // ── Section: Popular Services ────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: const SectionHeader(title: 'Popular Services'),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: _PopularServicesSection(isWide: isWide),
          ),
        ),

        // ── Section: Trust & Safety ───────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: const SectionHeader(title: 'Trust & Safety'),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.5),
                  ),
                ),
                child: const Column(
                  children: [
                    TrustPointTile(
                      icon: Icons.verified_user_rounded,
                      title: 'Verified professionals',
                      description:
                          'Every provider completes ID and background verification before taking jobs.',
                    ),
                    SizedBox(height: 16),
                    TrustPointTile(
                      icon: Icons.fact_check_rounded,
                      title: 'You approve the match',
                      description:
                          'Review your provider\'s profile and rating before they\'re assigned.',
                    ),
                    SizedBox(height: 16),
                    TrustPointTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Your address stays private',
                      description:
                          'Your exact address is only shared once a provider is confirmed.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Section: Offers ────────────────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: const SectionHeader(title: 'Offers for you'),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: OfferCard(
                title: '20% off your first repair',
                subtitle: 'Valid for new customers on any service category.',
                badgeLabel: 'NEW',
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.createTicket),
              ),
            ),
          ),
        ),

        // ── Active ticket preview ──────────────────────────────
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: SectionHeader(
                title: 'Active Tickets',
                actionLabel: 'See all',
                onActionTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.myTickets),
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

        // Bottom padding — extra clearance for the floating nav bar
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ── Category Grid ──────────────────────────────────────────────────
class _CategoryGrid extends StatefulWidget {
  final bool isWide;
  const _CategoryGrid({required this.isWide});

  @override
  State<_CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<_CategoryGrid> {
  int? _selectedIndex;

  void _handleTap(int index) {
    setState(() => _selectedIndex = index);
    Navigator.of(context).pushNamed(RouteNames.createTicket).then((_) {
      if (mounted) setState(() => _selectedIndex = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <({String label, IconData icon})>[
      for (final c in _realHomeCategories)
        (label: ServiceCategoryUi.label(c), icon: ServiceCategoryUi.icon(c)),
      ...kCosmeticOnlyCategoryTiles,
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.isWide ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) {
        final tile = tiles[i];
        return ServiceCategoryTile(
          label: tile.label,
          icon: tile.icon,
          selected: _selectedIndex == i,
          onTap: () => _handleTap(i),
        );
      },
    );
  }
}

// ── Popular Services ─────────────────────────────────────────────────
class _PopularServicesSection extends StatelessWidget {
  final bool isWide;
  const _PopularServicesSection({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final cards = _popularServices
        .map(
          (s) => PopularServiceCard(
            icon: s.icon,
            title: s.title,
            description: s.description,
            startingPrice: s.price,
            rating: s.rating,
            onTap: () =>
                Navigator.of(context).pushNamed(RouteNames.createTicket),
          ),
        )
        .toList();

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(spacing: 16, runSpacing: 16, children: cards),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => cards[i],
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
                    ServiceCategoryUi.icon(job.category),
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
                        ServiceCategoryUi.label(job.category),
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
}

// ── Tickets tab ──────────────────────────────────────────────────────
class _TicketsTab extends StatefulWidget {
  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
        title: const Text('My Tickets'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: AppTextStyles.titleMedium,
          unselectedLabelStyle: AppTextStyles.bodyMedium,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, userSnapshot) {
          final customerId = userSnapshot.data?.id;
          if (customerId == null) {
            return const LoadingWidget();
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _ActiveTicketsView(customerId: customerId),
              _HistoryTicketsView(customerId: customerId),
            ],
          );
        },
      ),
    );
  }
}

// ── Active tickets sub-view ─────────────────────────────────────────
class _ActiveTicketsView extends StatelessWidget {
  final String customerId;
  const _ActiveTicketsView({required this.customerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ticket>>(
      stream: TicketService.instance.watchMyTickets(customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }
        if (snapshot.hasError) {
          debugPrint('[ActiveTickets] watchMyTickets error: ${snapshot.error}');
          return EmptyStateWidget(
            icon: Icons.error_outline_rounded,
            title: 'Could not load tickets',
            subtitle: '${snapshot.error}',
          );
        }
        final allTickets = snapshot.data ?? [];
        final active = allTickets.where((t) => t.isActive).toList();

        // Also check for an active Job (from the in-memory JobService)
        final activeJob = JobService.instance.activeJobForCustomer(customerId);

        if (active.isEmpty && activeJob == null) {
          return const EmptyStateWidget(
            icon: Icons.check_circle_outline_rounded,
            title: 'No active tickets',
            subtitle: 'Raise a new service request using the + button',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: (activeJob != null ? 1 : 0) + active.length,
          itemBuilder: (context, i) {
            // Show active job card first
            if (activeJob != null && i == 0) {
              return _ActiveJobCard(job: activeJob);
            }
            final ticketIndex = i - (activeJob != null ? 1 : 0);
            final ticket = active[ticketIndex];
            return _TicketCard(ticket: ticket);
          },
        );
      },
    );
  }
}

// ── History tickets sub-view ─────────────────────────────────────────
class _HistoryTicketsView extends StatelessWidget {
  final String customerId;
  const _HistoryTicketsView({required this.customerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Ticket>>(
      stream: TicketService.instance.watchMyTickets(customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }
        if (snapshot.hasError) {
          debugPrint(
            '[HistoryTickets] watchMyTickets error: ${snapshot.error}',
          );
          return EmptyStateWidget(
            icon: Icons.error_outline_rounded,
            title: 'Could not load tickets',
            subtitle: '${snapshot.error}',
          );
        }
        final allTickets = snapshot.data ?? [];
        final history = allTickets.where((t) => !t.isActive).toList();

        // Also include completed/cancelled jobs from JobService
        final pastJobs = JobService.instance.completedJobsForProvider(
          customerId,
        );

        if (history.isEmpty && pastJobs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.history_rounded,
            title: 'No past tickets',
            subtitle: 'Completed and cancelled tickets will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: history.length,
          itemBuilder: (context, i) {
            return _TicketCard(ticket: history[i], isHistory: true);
          },
        );
      },
    );
  }
}

// ── Ticket card widget ──────────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final bool isHistory;

  const _TicketCard({required this.ticket, this.isHistory = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = TicketStatusUi.color(ticket.status);
    final statusLabel = TicketStatusUi.label(ticket.status);

    return GestureDetector(
      onTap: () {
        final job = JobService.instance.jobForTicket(ticket.id);
        if (job != null) {
          Navigator.of(
            context,
          ).pushNamed(RouteNames.jobTracking, arguments: job.jobId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Still finding a provider for this request.'),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.glassBorderDark
                : AppColors.divider.withValues(alpha: 0.5),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ServiceCategoryUi.iconBg(),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    ServiceCategoryUi.icon(ticket.category),
                    color: ServiceCategoryUi.iconFg(),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ServiceCategoryUi.label(ticket.category),
                        style: AppTextStyles.titleMedium.copyWith(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ticket.description.length > 50
                            ? '${ticket.description.substring(0, 50)}...'
                            : ticket.description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Footer: date and address
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  _formatDate(ticket.createdAt),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                if (ticket.addressLine != null &&
                    ticket.addressLine!.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      ticket.addressLine!,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab>
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
              _ProfileContent(
                user: user,
                nameController: _nameController,
                phoneController: _phoneController,
              ),
              _SettingsContent(
                user: user,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatefulWidget {
  final AppUser? user;
  final TextEditingController nameController;
  final TextEditingController phoneController;

  const _ProfileContent({
    required this.user,
    required this.nameController,
    required this.phoneController,
  });

  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
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
              Text(
                widget.user?.name ?? 'Customer User',
                style: AppTextStyles.headlineSmall,
              ),
              if (widget.user?.email.isNotEmpty ?? false) ...[
                const SizedBox(height: 2),
                Text(
                  widget.user!.email,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
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
            Text(
              'Basic Information',
              style: AppTextStyles.titleLarge,
            ),
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
          PrimaryButton(
            label: 'Save Changes',
            onPressed: _handleSave,
          ),
        ],
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
              borderSide: BorderSide(
                color: AppColors.divider,
              ),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

class _SettingsContent extends StatelessWidget {
  final AppUser? user;

  const _SettingsContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: [
        Text('App Preferences', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        _SettingsSection(
          title: 'Theme',
          icon: Icons.palette_outlined,
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
        _SettingsSection(
          title: 'Push Notifications',
          icon: Icons.notifications_outlined,
          child: StreamBuilder<bool>(
            stream: AppPreferencesService.instance.notificationsEnabledStream,
            initialData:
                AppPreferencesService.instance.notificationsEnabled,
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
                        'Updates on your requests',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: enabled,
                    onChanged: (value) {
                      AppPreferencesService.instance
                          .setNotificationsEnabled(value);
                    },
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
        _ProfileTile(
          icon: Icons.lock_outline_rounded,
          label: 'Change Password',
          onTap: () {},
        ),
        _ProfileTile(
          icon: Icons.verified_user_outlined,
          label: 'Email Verification Status',
          onTap: () {},
        ),
        const SizedBox(height: 24),
        Text('About', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        _ProfileTile(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          onTap: () {},
        ),
        _ProfileTile(
          icon: Icons.description_outlined,
          label: 'Terms of Service',
          onTap: () {},
        ),
        _ProfileTile(
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
        _ProfileTile(
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          isDestructive: true,
          onTap: () => Navigator.of(context)
              .pushReplacementNamed(RouteNames.roleSelection),
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
                color:
                    isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.child,
  });

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
