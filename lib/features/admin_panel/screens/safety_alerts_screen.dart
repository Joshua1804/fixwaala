import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../auth/services/auth_service.dart';
import '../../reports_safety/models/report_model.dart';
import '../../reports_safety/services/report_service.dart';

/// Admin's Safety Alerts Screen — every SOS raised, resolvable one by one.
class SafetyAlertsScreen extends StatefulWidget {
  const SafetyAlertsScreen({super.key});

  @override
  State<SafetyAlertsScreen> createState() => _SafetyAlertsScreenState();
}

class _SafetyAlertsScreenState extends State<SafetyAlertsScreen> {
  Future<void> _resolve(SafetyAlert alert) async {
    final admin = await AuthService.instance.currentUser();
    await ReportService.instance.resolveSafetyAlert(
      alert.id,
      adminId: admin?.id ?? 'admin',
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Safety alerts')),
      body: StreamBuilder<void>(
        stream: ReportService.instance.changes,
        builder: (context, _) {
          final alerts = ReportService.instance.allSafetyAlerts();
          if (alerts.isEmpty) {
            return Center(
              child: Text(
                'No safety alerts.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final alert = alerts[i];
              return Card(
                color: alert.resolved
                    ? null
                    : AppColors.error.withValues(alpha: 0.05),
                child: ListTile(
                  leading: Icon(
                    Icons.emergency,
                    color: alert.resolved
                        ? AppColors.textHint
                        : AppColors.error,
                  ),
                  title: Text('SOS from ${alert.userId}'),
                  subtitle: Text(alert.raisedAt.toString()),
                  trailing: alert.resolved
                      ? const Text('Resolved')
                      : SizedBox(
                          width: 100,
                          child: PrimaryButton(
                            label: 'Resolve',
                            height: 36,
                            onPressed: () => _resolve(alert),
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
