import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatting.dart';
import '../../core/admin_audit_service.dart';
import '../../widgets/admin_data_table.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_search_field.dart';
import '../../widgets/admin_state_views.dart';

/// Every privileged action taken through this website, newest first. Backed
/// by `auditEvents`, which `firestore.rules` makes admin-create,
/// nobody-update-or-delete — this list is a genuine record, not something
/// even an admin can quietly edit after the fact.
class AdminAuditLogScreen extends StatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  State<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends State<AdminAuditLogScreen> {
  String? _targetTypeFilter;
  String _search = '';

  static const _targetTypes = [
    'user',
    'ticket',
    'job',
    'payment',
    'report',
    'safetyAlert',
    'rating',
    'announcement',
    'platformSettings',
  ];

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Audit log',
      subtitle: 'The most recent 200 privileged actions.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AdminSearchField(
                hint: 'Filter by action or admin email…',
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                width: 300,
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String?>(
                  initialValue: _targetTypeFilter,
                  decoration: const InputDecoration(labelText: 'Target type'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All'),
                    ),
                    ..._targetTypes.map(
                      (t) =>
                          DropdownMenuItem<String?>(value: t, child: Text(t)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _targetTypeFilter = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          StreamBuilder<List<AuditEvent>>(
            stream: AdminAuditService.instance.watch(
              targetType: _targetTypeFilter,
              limit: 200,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AdminLoadingView();
              }
              if (snapshot.hasError) {
                return AdminErrorView(error: snapshot.error!);
              }
              var events = snapshot.data ?? [];
              if (_search.isNotEmpty) {
                events = events
                    .where(
                      (e) =>
                          e.action.toLowerCase().contains(_search) ||
                          e.actorAdminEmail.toLowerCase().contains(_search) ||
                          e.targetId.toLowerCase().contains(_search),
                    )
                    .toList();
              }
              if (events.isEmpty) {
                return const AdminEmptyView(
                  title: 'No matching events',
                  message:
                      'Nothing recorded yet, or nothing matches these filters.',
                  icon: Icons.history_rounded,
                );
              }
              return AdminTableCard(
                columns: const [
                  DataColumn(label: Text('When')),
                  DataColumn(label: Text('Admin')),
                  DataColumn(label: Text('Action')),
                  DataColumn(label: Text('Target')),
                ],
                rows: events.map((e) {
                  return DataRow(
                    cells: [
                      DataCell(Text(RelativeTime.format(e.createdAt))),
                      DataCell(Text(e.actorAdminEmail)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            e.action,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text('${e.targetType}/${e.targetId}')),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
