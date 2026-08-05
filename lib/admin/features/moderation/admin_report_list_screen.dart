import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/utils/formatting.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_data_table.dart';
import '../../widgets/admin_filter_dropdown.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_pagination_bar.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'services/admin_moderation_service.dart';

String reportStatusLabel(ReportStatus status) => switch (status) {
  ReportStatus.open => 'Open',
  ReportStatus.underReview => 'Under review',
  ReportStatus.resolved => 'Resolved',
  ReportStatus.rejected => 'Rejected',
};

AdminTone reportStatusTone(ReportStatus status) => switch (status) {
  ReportStatus.open => AdminTone.bad,
  ReportStatus.underReview => AdminTone.warning,
  ReportStatus.resolved => AdminTone.good,
  ReportStatus.rejected => AdminTone.neutral,
};

AdminTone severityTone(ReportSeverity severity) => switch (severity) {
  ReportSeverity.low => AdminTone.neutral,
  ReportSeverity.medium => AdminTone.warning,
  ReportSeverity.high => AdminTone.bad,
};

class AdminReportListScreen extends StatefulWidget {
  const AdminReportListScreen({super.key});

  @override
  State<AdminReportListScreen> createState() => _AdminReportListScreenState();
}

class _AdminReportListScreenState extends State<AdminReportListScreen> {
  ReportStatus? _status;
  final List<fs.DocumentSnapshot<Map<String, dynamic>>?> _cursorStack = [null];
  int _pageIndex = 0;
  Future<ReportPage>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminModerationService.instance.fetchReportPage(
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
      title: 'Reports',
      subtitle: 'User-filed reports, awaiting review or resolved.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminFilterDropdown<ReportStatus>(
            label: 'Status',
            value: _status,
            options: ReportStatus.values,
            labelBuilder: reportStatusLabel,
            onChanged: (v) {
              setState(() => _status = v);
              _reset();
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<ReportPage>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AdminLoadingView();
              }
              if (snapshot.hasError) {
                return AdminErrorView(error: snapshot.error!, onRetry: _reset);
              }
              final page = snapshot.data!;
              if (page.reports.isEmpty && _pageIndex == 0) {
                return const AdminEmptyView(
                  title: 'No reports',
                  message: 'No reports match this filter.',
                  icon: Icons.flag_outlined,
                );
              }
              return Column(
                children: [
                  AdminTableCard(
                    columns: const [
                      DataColumn(label: Text('Reason')),
                      DataColumn(label: Text('Severity')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Filed')),
                    ],
                    rows: page.reports.map((report) {
                      return DataRow(
                        onSelectChanged: (_) => Navigator.of(context).pushNamed(
                          AdminRouteNames.reportDetail,
                          arguments: report.id,
                        ),
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 320,
                              child: Text(
                                report.reason,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            AdminStatusChip.semantic(
                              report.severity.name,
                              tone: severityTone(report.severity),
                            ),
                          ),
                          DataCell(
                            AdminStatusChip.semantic(
                              reportStatusLabel(report.status),
                              tone: reportStatusTone(report.status),
                            ),
                          ),
                          DataCell(Text(RelativeTime.format(report.createdAt))),
                        ],
                      );
                    }).toList(),
                  ),
                  AdminPaginationBar(
                    pageNumber: _pageIndex + 1,
                    pageSize: 25,
                    currentCount: page.reports.length,
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
