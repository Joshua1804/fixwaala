import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/services/auth_service.dart';
import '../../reports_safety/models/report_model.dart';
import '../../reports_safety/services/report_service.dart';

/// Admin's Reports and Disputes Screen — review evidence and set a report's
/// status to Open, Under Review, Resolved, or Rejected.
class ReportsManagementScreen extends StatefulWidget {
  const ReportsManagementScreen({super.key});

  @override
  State<ReportsManagementScreen> createState() =>
      _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  Future<void> _openDetail(Report report) async {
    final admin = await AuthService.instance.currentUser();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReportDetailSheet(
        report: report,
        adminId: admin?.id ?? 'admin',
        onChanged: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & disputes')),
      body: StreamBuilder<void>(
        stream: ReportService.instance.changes,
        builder: (context, _) {
          final reports = ReportService.instance.allReports();
          if (reports.isEmpty) {
            return Center(
              child: Text(
                'No reports yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = reports[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.report),
                  title: Text(r.reason),
                  subtitle: Text(
                    r.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _statusBadge(r.status),
                  onTap: () => _openDetail(r),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusBadge(ReportStatus status) => switch (status) {
    ReportStatus.open => StatusBadge.warning('Open'),
    ReportStatus.underReview => StatusBadge.info('Under review'),
    ReportStatus.resolved => StatusBadge.success('Resolved'),
    ReportStatus.rejected => StatusBadge.neutral('Rejected'),
  };
}

class _ReportDetailSheet extends StatefulWidget {
  final Report report;
  final String adminId;
  final VoidCallback onChanged;

  const _ReportDetailSheet({
    required this.report,
    required this.adminId,
    required this.onChanged,
  });

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  bool _busy = false;

  Future<void> _setStatus(ReportStatus status) async {
    setState(() => _busy = true);
    await ReportService.instance.updateReportStatus(
      widget.report.id,
      status,
      adminId: widget.adminId,
    );
    if (!mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.reason, style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Severity: ${r.severity.name}',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(r.description),
          if (r.evidenceUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Evidence', style: AppTextStyles.titleMedium),
            for (final url in r.evidenceUrls)
              Text(url, style: AppTextStyles.caption),
          ],
          const SizedBox(height: 20),
          Text('Set status', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusButton(ReportStatus.open, 'Open'),
              _statusButton(ReportStatus.underReview, 'Under review'),
              _statusButton(ReportStatus.resolved, 'Resolved'),
              _statusButton(ReportStatus.rejected, 'Rejected'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusButton(ReportStatus status, String label) {
    final isCurrent = widget.report.status == status;
    return OutlinedButton(
      onPressed: _busy || isCurrent ? null : () => _setStatus(status),
      child: Text(label),
    );
  }
}
