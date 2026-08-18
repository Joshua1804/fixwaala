import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../core/admin_auth_service.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import 'models/platform_settings.dart';
import 'services/platform_settings_service.dart';

class AdminPlatformSettingsScreen extends StatefulWidget {
  const AdminPlatformSettingsScreen({super.key});

  @override
  State<AdminPlatformSettingsScreen> createState() =>
      _AdminPlatformSettingsScreenState();
}

class _AdminPlatformSettingsScreenState
    extends State<AdminPlatformSettingsScreen> {
  Future<PlatformSettings>? _future;

  bool _maintenanceMode = false;
  late TextEditingController _maintenanceMessage;
  late TextEditingController _supportEmail;
  late TextEditingController _supportPhone;
  late TextEditingController _minVersion;
  late TextEditingController _candidateReviewSeconds;
  late TextEditingController _radii;

  bool _saving = false;
  String? _saveError;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _maintenanceMessage = TextEditingController();
    _supportEmail = TextEditingController();
    _supportPhone = TextEditingController();
    _minVersion = TextEditingController();
    _candidateReviewSeconds = TextEditingController();
    _radii = TextEditingController();
    _load();
  }

  void _load() {
    _future = PlatformSettingsService.instance.fetch()..then(_populate);
  }

  void _populate(PlatformSettings settings) {
    if (!mounted) return;
    setState(() {
      _maintenanceMode = settings.maintenanceMode;
      _maintenanceMessage.text = settings.maintenanceMessage;
      _supportEmail.text = settings.supportEmail;
      _supportPhone.text = settings.supportPhone;
      _minVersion.text = settings.minSupportedAppVersion;
      _candidateReviewSeconds.text = settings.candidateReviewSeconds.toString();
      _radii.text = settings.searchRadiiKm
          .map((r) => r.toStringAsFixed(0))
          .join(', ');
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _maintenanceMessage.dispose();
    _supportEmail.dispose();
    _supportPhone.dispose();
    _minVersion.dispose();
    _candidateReviewSeconds.dispose();
    _radii.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final radii = _radii.text
          .split(',')
          .map((s) => double.tryParse(s.trim()))
          .whereType<double>()
          .toList();
      final settings = PlatformSettings(
        maintenanceMode: _maintenanceMode,
        maintenanceMessage: _maintenanceMessage.text.trim(),
        supportEmail: _supportEmail.text.trim(),
        supportPhone: _supportPhone.text.trim(),
        searchRadiiKm: radii.isEmpty ? const [5, 10, 15] : radii,
        candidateReviewSeconds:
            int.tryParse(_candidateReviewSeconds.text.trim()) ?? 180,
        minSupportedAppVersion: _minVersion.text.trim().isEmpty
            ? '1.0.0'
            : _minVersion.text.trim(),
      );
      await PlatformSettingsService.instance.save(
        settings,
        adminId: AdminAuthService.instance.currentUid ?? 'unknown',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Platform settings',
      subtitle: 'Not yet read by the Android app — see the note below.',
      child: FutureBuilder<PlatformSettings>(
        future: _future,
        builder: (context, snapshot) {
          if (!_loaded && snapshot.connectionState == ConnectionState.waiting) {
            return const AdminLoadingView();
          }
          if (snapshot.hasError && !_loaded) {
            return AdminErrorView(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.info,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'These values are stored in Firestore but the Android '
                          'app still compiles its own copy (AppConstants) at '
                          'build time. Changing them here does not change '
                          'in-app behavior until the app is wired to read this '
                          'document — see docs/ADMIN_WEB.md.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Maintenance', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Maintenance mode'),
                  value: _maintenanceMode,
                  onChanged: (v) => setState(() => _maintenanceMode = v),
                ),
                TextField(
                  controller: _maintenanceMessage,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Maintenance message shown to users',
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Support', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _supportEmail,
                  decoration: const InputDecoration(labelText: 'Support email'),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _supportPhone,
                  decoration: const InputDecoration(labelText: 'Support phone'),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Matching tunables', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _radii,
                  decoration: const InputDecoration(
                    labelText: 'Search radii (km, comma-separated)',
                    hintText: '5, 10, 15',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _candidateReviewSeconds,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Candidate review window (seconds)',
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('Release', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _minVersion,
                  decoration: const InputDecoration(
                    labelText: 'Minimum supported app version',
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                if (_saveError != null) ...[
                  Text(
                    _saveError!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save settings'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
