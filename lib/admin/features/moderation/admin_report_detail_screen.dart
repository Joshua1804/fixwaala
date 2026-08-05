import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatting.dart';
import '../../../features/reports_safety/models/report_model.dart';
import '../../core/admin_auth_service.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'admin_report_list_screen.dart';
import 'services/admin_moderation_service.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final String reportId;
  const AdminReportDetailScreen({super.key, required this.reportId});

  @override
  State<AdminReportDetailScreen> createState() =>
      _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> {
  late Future<Report?> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = AdminModerationService.instance.fetchReport(widget.reportId);

  Future<void> _setStatus(Report report, ReportStatus status) async {
    final noteController = TextEditingController(text: report.adminNote ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set status: ${reportStatusLabel(status)}'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Admin note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(noteController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (note == null) return;
    setState(() => _busy = true);
    await AdminModerationService.instance.resolveReport(
      report,
      status: status,
      adminNote: note,
      adminId: AdminAuthService.instance.currentUid ?? 'unknown',
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reportId.isEmpty) {
      return const Scaffold(
        body: AdminEmptyView(
          title: 'No report selected',
          message: 'Open this screen from the Reports list.',
        ),
      );
    }
    return FutureBuilder<Report?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: AdminLoadingView());
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: AdminErrorView(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            ),
          );
        }
        final report = snapshot.data;
        if (report == null) {
          return const Scaffold(
            body: AdminEmptyView(
              title: 'Report not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        return AdminPageScaffold(
          title: 'Report ${report.id}',
          subtitle: report.reason,
          actions: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            IconButton(
              tooltip: 'Open reporter profile',
              onPressed: () => Navigator.of(context).pushNamed(
                AdminRouteNames.userDetail,
                arguments: report.reporterId,
              ),
              icon: const Icon(Icons.person_outline_rounded),
            ),
            if (report.againstUserId != null)
              IconButton(
                tooltip: 'Open reported user profile',
                onPressed: () => Navigator.of(context).pushNamed(
                  AdminRouteNames.userDetail,
                  arguments: report.againstUserId,
                ),
                icon: const Icon(Icons.person_search_outlined),
              ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  AdminStatusChip.semantic(
                    reportStatusLabel(report.status),
                    tone: reportStatusTone(report.status),
                  ),
                  AdminStatusChip.semantic(
                    '${report.severity.name} severity',
                    tone: severityTone(report.severity),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              _Section(
                title: 'Report',
                rows: [
                  _row('Reason', report.reason),
                  _row('Description', report.description),
                  if (report.ticketId != null) _row('Ticket', report.ticketId!),
                  if (report.jobId != null) _row('Job', report.jobId!),
                  _row('Filed', RelativeTime.format(report.createdAt)),
                ],
              ),
              if (report.evidenceUrls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('Evidence', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: report.evidenceUrls.map((url) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          width: 120,
                          height: 120,
                          color: AppColors.background,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
              _Section(
                title: 'Resolution',
                rows: [
                  if (report.adminNote != null) _row('Admin note', report.adminNote!),
                  if (report.resolvedByAdminId != null)
                    _row('Resolved by', report.resolvedByAdminId!),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      if (report.status != ReportStatus.underReview)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _setStatus(report, ReportStatus.underReview),
                          child: const Text('Mark under review'),
                        ),
                      if (report.status != ReportStatus.resolved)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _setStatus(report, ReportStatus.resolved),
                          child: const Text('Resolve'),
                        ),
                      if (report.status != ReportStatus.rejected)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: BorderSide(
                              color: AppColors.textSecondary.withValues(alpha: 0.4),
                            ),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _setStatus(report, ReportStatus.rejected),
                          child: const Text('Reject'),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) => _DetailRow(label: label, value: value);
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...rows,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}
