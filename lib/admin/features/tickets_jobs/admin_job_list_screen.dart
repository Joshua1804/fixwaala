import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../../features/service_lifecycle/widgets/job_status_ui.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_data_table.dart';
import '../../widgets/admin_filter_dropdown.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_pagination_bar.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'services/admin_ticket_job_service.dart';

class AdminJobListScreen extends StatefulWidget {
  const AdminJobListScreen({super.key});

  @override
  State<AdminJobListScreen> createState() => _AdminJobListScreenState();
}

class _AdminJobListScreenState extends State<AdminJobListScreen> {
  JobStatus? _status;
  final List<fs.DocumentSnapshot<Map<String, dynamic>>?> _cursorStack = [null];
  int _pageIndex = 0;
  Future<JobPage>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminTicketJobService.instance.fetchJobPage(
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
      title: 'Jobs',
      subtitle: 'Every confirmed job, across the platform.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminFilterDropdown<JobStatus>(
            label: 'Status',
            value: _status,
            options: JobStatus.values,
            labelBuilder: JobStatusUi.label,
            onChanged: (v) {
              setState(() => _status = v);
              _reset();
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<JobPage>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AdminLoadingView();
              }
              if (snapshot.hasError) {
                return AdminErrorView(error: snapshot.error!, onRetry: _reset);
              }
              final page = snapshot.data!;
              if (page.jobs.isEmpty && _pageIndex == 0) {
                return const AdminEmptyView(
                  title: 'No jobs',
                  message: 'No jobs match this filter.',
                  icon: Icons.work_outline_rounded,
                );
              }
              return Column(
                children: [
                  AdminTableCard(
                    columns: const [
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Provider')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Paid')),
                      DataColumn(label: Text('Created')),
                    ],
                    rows: page.jobs.map((job) {
                      return DataRow(
                        onSelectChanged: (_) => Navigator.of(context).pushNamed(
                          AdminRouteNames.jobDetail,
                          arguments: job.jobId,
                        ),
                        cells: [
                          DataCell(Text(job.customerName)),
                          DataCell(Text(job.providerName)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ServiceCategoryUi.icon(job.category),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(ServiceCategoryUi.label(job.category)),
                              ],
                            ),
                          ),
                          DataCell(
                            AdminStatusChip(
                              label: JobStatusUi.label(job.status),
                              color: JobStatusUi.color(job.status),
                            ),
                          ),
                          DataCell(
                            Icon(
                              job.paid
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: job.paid
                                  ? AppColors.success
                                  : AppColors.textHint,
                            ),
                          ),
                          DataCell(Text(RelativeTime.format(job.createdAt))),
                        ],
                      );
                    }).toList(),
                  ),
                  AdminPaginationBar(
                    pageNumber: _pageIndex + 1,
                    pageSize: 25,
                    currentCount: page.jobs.length,
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
