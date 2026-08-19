import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/widgets/async_state_builder.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../auth/services/auth_service.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/ticket_model.dart';
import '../services/ticket_service.dart';
import '../widgets/ticket_status_ui.dart';
import '../../../core/utils/formatting.dart';

/// Full-page "My Tickets" accessible from the Tickets tab → "See all".
/// Provides the same Active / History tabs as the embedded tab, but as a
/// standalone navigable screen.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen>
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
        title: const Text('My Requests'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: FutureBuilder(
        future: AuthService.instance.currentUser(),
        builder: (context, snapshot) {
          final customerId = snapshot.data?.id;
          if (customerId == null) {
            return const LoadingWidget();
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _TicketListView(customerId: customerId, showActive: true),
              _TicketListView(customerId: customerId, showActive: false),
            ],
          );
        },
      ),
    );
  }
}

class _TicketListView extends StatelessWidget {
  final String customerId;
  final bool showActive;
  const _TicketListView({required this.customerId, required this.showActive});

  @override
  Widget build(BuildContext context) {
    return AsyncStateBuilder.stream<List<Ticket>>(
      stream: TicketService.instance.watchMyTickets(customerId),
      isEmpty: (all) {
        final filtered = showActive
            ? all.where((t) => t.isActive)
            : all.where((t) => !t.isActive);
        return filtered.isEmpty;
      },
      empty: EmptyStateWidget(
        icon: showActive
            ? Icons.check_circle_outline_rounded
            : Icons.history_rounded,
        title: showActive ? 'No active requests' : 'No past requests',
        subtitle: showActive
            ? 'New service requests will appear here'
            : 'Completed and cancelled requests will appear here',
      ),
      data: (context, all) {
        final filtered = showActive
            ? all.where((t) => t.isActive).toList()
            : all.where((t) => !t.isActive).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final ticket = filtered[i];
            return _TicketHistoryCard(ticket: ticket);
          },
        );
      },
    );
  }
}

class _TicketHistoryCard extends StatelessWidget {
  final Ticket ticket;
  const _TicketHistoryCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = TicketStatusUi.color(ticket.status);

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
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ticket.description.length > 60
                            ? '${ticket.description.substring(0, 60)}...'
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
                    TicketStatusUi.label(ticket.status),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
