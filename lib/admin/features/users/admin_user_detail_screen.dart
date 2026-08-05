import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../widgets/admin_confirm_dialog.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'services/admin_user_service.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;
  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late Future<AppUser?> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = AdminUserService.instance.fetchOne(widget.userId);

  Future<void> _editProfile(AppUser user) async {
    final nameController = TextEditingController(text: user.name ?? '');
    final phoneController = TextEditingController(text: user.phone ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != true) return;
    setState(() => _busy = true);
    await AdminUserService.instance.updateProfile(
      user,
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
  }

  Future<void> _changeStatus(AppUser user, AccountStatus status) async {
    final reason = await showAdminReasonDialog(
      context,
      title: status == AccountStatus.active
          ? 'Reactivate account'
          : 'Set account to ${status.name}',
      label: 'Reason (recorded in the audit log)',
    );
    if (reason == null) return;
    setState(() => _busy = true);
    await AdminUserService.instance.setAccountStatus(
      user,
      status,
      reason: reason,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
  }

  Future<void> _toggleVerified(AppUser user) async {
    final next = !user.isVerified;
    final confirmed = await showAdminConfirmDialog(
      context,
      title: next ? 'Grant Verified badge' : 'Remove Verified badge',
      message: next
          ? '${user.name ?? user.email} will show the Verified badge to '
                'customers reviewing them as a candidate.'
          : 'The Verified badge will no longer show for '
                '${user.name ?? user.email}.',
      confirmLabel: next ? 'Grant' : 'Remove',
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    await AdminUserService.instance.setVerified(user, next);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
  }

  Future<void> _delete(AppUser user) async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Delete profile',
      message:
          'This deletes ${user.email}\'s Firestore profile. Their tickets, '
          'jobs, and payment history are kept as historical records. This '
          'does NOT delete their Firebase Auth login — run '
          '"node scripts/admin/delete_user.js ${user.email}" separately to '
          'remove that. This cannot be undone from this screen.',
      confirmLabel: 'Delete profile',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    await AdminUserService.instance.deleteProfile(user);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return const Scaffold(
        body: AdminEmptyView(
          title: 'No user selected',
          message: 'Open this screen from the Users list.',
          icon: Icons.link_off_rounded,
        ),
      );
    }
    return FutureBuilder<AppUser?>(
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
        final user = snapshot.data;
        if (user == null) {
          return const Scaffold(
            body: AdminEmptyView(
              title: 'User not found',
              message: 'This profile may have already been deleted.',
            ),
          );
        }
        return AdminPageScaffold(
          title: user.name?.trim().isNotEmpty == true ? user.name! : user.email,
          subtitle: user.email,
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
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _editProfile(user),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            if (user.role == UserRole.provider)
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _toggleVerified(user),
                icon: Icon(
                  user.isVerified
                      ? Icons.remove_circle_outline_rounded
                      : Icons.verified_outlined,
                  size: 18,
                ),
                label: Text(user.isVerified ? 'Unverify' : 'Verify'),
              ),
            if (user.accountStatus != AccountStatus.suspended)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _changeStatus(user, AccountStatus.suspended),
                icon: const Icon(Icons.block_rounded, size: 18),
                label: const Text('Suspend'),
              ),
            if (user.accountStatus != AccountStatus.active)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _changeStatus(user, AccountStatus.active),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Reactivate'),
              ),
            if (user.accountStatus == AccountStatus.active)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _changeStatus(user, AccountStatus.restricted),
                icon: const Icon(Icons.warning_amber_rounded, size: 18),
                label: const Text('Restrict'),
              ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              onPressed: _busy ? null : () => _delete(user),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
            ),
          ],
          child: _UserDetailBody(user: user),
        );
      },
    );
  }
}

class _UserDetailBody extends StatelessWidget {
  final AppUser user;
  const _UserDetailBody({required this.user});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AdminStatusChip.semantic(
              user.role == UserRole.customer ? 'Customer' : 'Provider',
              tone: user.role == UserRole.customer
                  ? AdminTone.neutral
                  : AdminTone.good,
            ),
            switch (user.accountStatus) {
              AccountStatus.active =>
                AdminStatusChip.semantic('Active', tone: AdminTone.good),
              AccountStatus.restricted => AdminStatusChip.semantic(
                'Restricted',
                tone: AdminTone.warning,
              ),
              AccountStatus.suspended =>
                AdminStatusChip.semantic('Suspended', tone: AdminTone.bad),
            },
            if (user.role == UserRole.provider)
              AdminStatusChip.semantic(
                user.isVerified ? 'Verified' : 'Not verified',
                tone: user.isVerified ? AdminTone.good : AdminTone.neutral,
              ),
            if (!user.emailVerified)
              AdminStatusChip.semantic(
                'Email not verified',
                tone: AdminTone.warning,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        _Section(
          title: 'Account',
          rows: [
            _row('Email', user.email),
            _row('Phone', user.phone ?? '—'),
            _row('Joined', RelativeTime.format(user.createdAt)),
            _row(
              'Onboarding',
              user.onboardingComplete ? 'Complete' : 'Incomplete',
            ),
            if (user.updatedAt != null)
              _row('Last updated', RelativeTime.format(user.updatedAt!)),
          ],
        ),
        if (user.customerProfile != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          _Section(
            title: 'Customer profile',
            rows: [
              _row('Address label', user.customerProfile!.addressLabel ?? '—'),
              _row('Address', user.customerProfile!.addressLine ?? '—'),
              _row('City', user.customerProfile!.city ?? '—'),
              _row('Pincode', user.customerProfile!.pincode ?? '—'),
            ],
          ),
        ],
        if (user.providerProfile != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          _Section(
            title: 'Provider profile',
            rows: [
              _row(
                'Skills',
                user.providerProfile!.skills.isEmpty
                    ? '—'
                    : user.providerProfile!.skills
                          .map(ServiceCategoryUi.label)
                          .join(', '),
              ),
              _row(
                'Experience',
                user.providerProfile!.experienceYears != null
                    ? '${user.providerProfile!.experienceYears} years'
                    : '—',
              ),
              _row('Service area', user.providerProfile!.serviceArea ?? '—'),
              _row('Availability', user.providerProfile!.availability ?? '—'),
              _row('Online now', user.providerProfile!.online ? 'Yes' : 'No'),
            ],
          ),
        ],
      ],
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
            width: 160,
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
