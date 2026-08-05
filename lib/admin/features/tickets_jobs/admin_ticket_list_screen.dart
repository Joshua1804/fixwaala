import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../../features/customer_ticket/widgets/ticket_status_ui.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_data_table.dart';
import '../../widgets/admin_filter_dropdown.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_pagination_bar.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'services/admin_ticket_job_service.dart';

class AdminTicketListScreen extends StatefulWidget {
  const AdminTicketListScreen({super.key});

  @override
  State<AdminTicketListScreen> createState() => _AdminTicketListScreenState();
}

class _AdminTicketListScreenState extends State<AdminTicketListScreen> {
  TicketStatus? _status;
  final List<fs.DocumentSnapshot<Map<String, dynamic>>?> _cursorStack = [null];
  int _pageIndex = 0;
  Future<TicketPage>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminTicketJobService.instance.fetchTicketPage(
      status: _status,
      startAfter: _cursorStack[_pageIndex],
    );
  }

  void _reset() => setState(() {
    _cursorStack
      ..clear()
      ..add(null);
    _pageIndex = 0;
    _load();
  });

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Tickets',
      subtitle: 'Every customer request, across the platform.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminFilterDropdown<TicketStatus>(
            label: 'Status',
            value: _status,
            options: TicketStatus.values,
            labelBuilder: TicketStatusUi.label,
            onChanged: (v) {
              setState(() => _status = v);
              _reset();
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<TicketPage>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AdminLoadingView();
              }
              if (snapshot.hasError) {
                return AdminErrorView(error: snapshot.error!, onRetry: _reset);
              }
              final page = snapshot.data!;
              if (page.tickets.isEmpty && _pageIndex == 0) {
                return const AdminEmptyView(
                  title: 'No tickets',
                  message: 'No tickets match this filter.',
                  icon: Icons.confirmation_number_outlined,
                );
              }
              return Column(
                children: [
                  AdminTableCard(
                    columns: const [
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Created')),
                    ],
                    rows: page.tickets.map((ticket) {
                      return DataRow(
                        onSelectChanged: (_) => Navigator.of(context).pushNamed(
                          AdminRouteNames.ticketDetail,
                          arguments: ticket.id,
                        ),
                        cells: [
                          DataCell(Text(ticket.customerName.isNotEmpty
                              ? ticket.customerName
                              : ticket.customerFirstName)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ServiceCategoryUi.icon(ticket.category),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(ServiceCategoryUi.label(ticket.category)),
                              ],
                            ),
                          ),
                          DataCell(
                            AdminStatusChip(
                              label: TicketStatusUi.label(ticket.status),
                              color: TicketStatusUi.color(ticket.status),
                            ),
                          ),
                          DataCell(Text(RelativeTime.format(ticket.createdAt))),
                        ],
                      );
                    }).toList(),
                  ),
                  AdminPaginationBar(
                    pageNumber: _pageIndex + 1,
                    pageSize: 25,
                    currentCount: page.tickets.length,
                    hasPrevious: _pageIndex > 0,
                    hasNext: page.hasMore,
                    isLoading: false,
                    onPrevious: _pageIndex == 0
                        ? null
                        : () => setState(() {
                            _pageIndex--;
                            _load();
                          }),
                    onNext: () => setState(() {
                      if (_pageIndex + 1 >= _cursorStack.length) {
                        _cursorStack.add(page.lastDoc);
                      }
                      _pageIndex++;
                      _load();
                    }),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
