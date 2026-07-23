import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../services/admin_service.dart';

/// Admin's Audit Events Screen — a log of every important moderation
/// action an admin has taken (account restrictions, suspensions, etc.).
class AuditEventsScreen extends StatelessWidget {
  const AuditEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final events = AdminService.instance.auditEvents();
    return Scaffold(
      appBar: AppBar(title: const Text('Audit events')),
      body: events.isEmpty
          ? Center(
              child: Text(
                'No audit events yet.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = events[i];
                return ListTile(
                  leading: const Icon(
                    Icons.history_rounded,
                    color: AppColors.textSecondary,
                  ),
                  title: Text(e.action),
                  subtitle: Text(
                    [
                      if (e.targetId != null) 'Target: ${e.targetId}',
                      if (e.payload['reason'] != null)
                        'Reason: ${e.payload['reason']}',
                    ].join(' • '),
                  ),
                  trailing: Text(
                    e.createdAt.toString().split('.').first,
                    style: AppTextStyles.caption,
                  ),
                );
              },
            ),
    );
  }
}
