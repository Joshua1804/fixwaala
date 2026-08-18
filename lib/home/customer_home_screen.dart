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
import '../core/widgets/empty_state_widget.dart';
import '../core/widgets/floating_nav_bar.dart';
import '../core/widgets/hero_banner.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/popular_service_card.dart';
import '../core/widgets/section_header.dart';
import '../core/widgets/service_category_tile.dart';
import '../core/widgets/service_category_ui.dart';
import '../core/widgets/status_badge.dart';
import '../core/widgets/trust_point_tile.dart';
import '../core/widgets/profile/profile_settings_scaffold.dart';
import '../core/widgets/profile/profile_tile.dart';
import '../core/utils/formatting.dart';
import '../core/widgets/cancel_request_action.dart';

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

/// Common problems, used as shortcuts into ticket creation with the category
/// pre-selected.
///
/// These previously carried invented starting prices ("From ₹399") and
/// invented ratings (4.7), none of which the system produces or honours, plus
/// a "Deep Home Cleaning" entry for a service the app cannot fulfil at all.
/// They are now purely navigational.
const _commonProblems = [
  (
    icon: Icons.plumbing,
    title: 'Leaks & blocked drains',
    description: 'Dripping taps, burst pipes, slow drains',
    category: ServiceCategory.plumber,
  ),
  (
    icon: Icons.electrical_services,
    title: 'Switches & wiring',
    description: 'Dead sockets, tripping breakers, new points',
    category: ServiceCategory.electrician,
  ),
  (
    icon: Icons.chair_alt,
    title: 'Furniture & fittings',
    description: 'Wobbly chairs, sticking doors, cabinets',
    category: ServiceCategory.carpenter,
  ),
  (
    icon: Icons.hvac_rounded,
    title: 'Something else',
    description: "Describe it and we'll work out who to send",
    category: ServiceCategory.unknown,
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
                            child: StreamBuilder<AppUser?>(
                              stream: AuthService.instance.currentUserStream,
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
                    'Rated professionals, transparent pricing, and safe bookings.',
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
                      icon: Icons.star_rounded,
                      title: 'Rated by real customers',
                      description:
                          'See every provider\'s rating and completed job count before you choose.',
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

  /// Carries the tapped category into ticket creation.
  ///
  /// This used to navigate with no arguments, so a customer who picked
  /// "Plumbing" then watched the AI re-derive the category from their free
  /// text — and sometimes disagree with them.
  void _handleTap(int index, ServiceCategory category) {
    setState(() => _selectedIndex = index);
    Navigator.of(context)
        .pushNamed(RouteNames.createTicket, arguments: {'category': category})
        .then((_) {
          if (mounted) setState(() => _selectedIndex = null);
        });
  }

  @override
  Widget build(BuildContext context) {
    // `kCosmeticOnlyCategoryTiles` ("Appliance Repair", "Cleaning") padded
    // this grid to six tiles for a brief. Tapping them opened a generic
    // request for a service the app has no category, no providers, and no way
    // to fulfil — so they are gone.
    final tiles = [
      for (final c in _realHomeCategories)
        (
          label: ServiceCategoryUi.label(c),
          icon: ServiceCategoryUi.icon(c),
          category: c,
        ),
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
          onTap: () => _handleTap(i, tile.category),
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
    final cards = _commonProblems
        .map(
          (s) => PopularServiceCard(
            icon: s.icon,
            title: s.title,
            description: s.description,
            onTap: () => Navigator.of(context).pushNamed(
              RouteNames.createTicket,
              arguments: {'category': s.category},
            ),
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

        // The ticket behind the active job is already represented by
        // _ActiveJobCard. Rendering it again showed the customer the same
        // request twice, described in two different status vocabularies
        // (JobStatus on one card, TicketStatus on the other).
        final others = activeJob == null
            ? active
            : active.where((t) => t.id != activeJob.ticketId).toList();

        // No RefreshIndicator here deliberately: this list is backed by a
        // live Firestore stream, so a pull gesture would have nothing to
        // re-fetch. A refresh control that does nothing is the same kind of
        // theatre as a save button that does not save.
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: (activeJob != null ? 1 : 0) + others.length,
          itemBuilder: (context, i) {
            if (activeJob != null && i == 0) {
              return _ActiveJobCard(job: activeJob);
            }
            final ticket = others[i - (activeJob != null ? 1 : 0)];
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

        // This previously also called `completedJobsForProvider(customerId)` —
        // a provider lookup handed a customer id, so it always returned an
        // empty list, and the result was never rendered anyway. The tickets
        // themselves are the history; they only started reaching a terminal
        // status once job transitions began mirroring onto them.
        if (history.isEmpty) {
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
          return;
        }
        switch (ticket.status) {
          case TicketStatus.matching:
            Navigator.of(
              context,
            ).pushNamed(RouteNames.matchingProgress, arguments: ticket.id);
            break;
          case TicketStatus.awaitingCustomerConfirmation:
            Navigator.of(
              context,
            ).pushNamed(RouteNames.providerReview, arguments: ticket.id);
            break;
          default:
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
                  RelativeTime.format(ticket.createdAt),
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
                const Spacer(),
                // A customer could not withdraw a request from anywhere in
                // the app. Cancelling is only offered while the request has
                // not yet been taken on by a provider.
                if (!isHistory && _isCancellable(ticket.status))
                  TextButton(
                    onPressed: () =>
                        CancelRequestAction.run(context, ticketId: ticket.id),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text('Cancel', style: AppTextStyles.caption),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Cancelling is free before anyone is on the hook. Once a provider is
  /// assigned and travelling, withdrawing is a job-level decision with a
  /// cancellation policy attached, not a one-tap action on a list row.
  static bool _isCancellable(TicketStatus status) =>
      status == TicketStatus.matching ||
      status == TicketStatus.awaitingCustomerConfirmation ||
      status == TicketStatus.draft;
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return ProfileSettingsScaffold(
      fallbackName: 'Customer User',
      notificationsSubtitle: 'Updates on your requests',
      tilesBuilder: (context, user) => [
        ProfileTile(
          icon: Icons.history_rounded,
          label: 'Order History',
          onTap: () => Navigator.of(context).pushNamed(RouteNames.myTickets),
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
        ProfileTile(
          icon: Icons.info_outline_rounded,
          label: 'About Fixwaala',
          onTap: () => Navigator.of(context).pushNamed(RouteNames.about),
        ),
      ],
    );
  }
}
