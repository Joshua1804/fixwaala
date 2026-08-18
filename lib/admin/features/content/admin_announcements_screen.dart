import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatting.dart';
import '../../core/admin_auth_service.dart';
import '../../widgets/admin_confirm_dialog.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'models/announcement.dart';
import 'services/announcement_service.dart';

Color _priorityColor(AnnouncementPriority p) => switch (p) {
  AnnouncementPriority.info => AppColors.info,
  AnnouncementPriority.warning => AppColors.warning,
  AnnouncementPriority.critical => AppColors.error,
};

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  Future<void> _openEditor([Announcement? existing]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _AnnouncementEditorDialog(existing: existing),
    );
  }

  Future<void> _delete(Announcement announcement) async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Delete announcement',
      message: 'Permanently delete "${announcement.title}"?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await AnnouncementService.instance.delete(announcement);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _toggleActive(Announcement announcement) async {
    try {
      await AnnouncementService.instance.setActive(
        announcement,
        !announcement.active,
      );
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Something went wrong: $error'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Announcements',
      subtitle:
          'In-app banners — the closest thing to notification management '
          'without a deployed push backend (see Monitoring).',
      actions: [
        FilledButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New announcement'),
        ),
      ],
      child: StreamBuilder<List<Announcement>>(
        stream: AnnouncementService.instance.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AdminLoadingView();
          }
          if (snapshot.hasError) {
            return AdminErrorView(error: snapshot.error!);
          }
          final announcements = snapshot.data ?? [];
          if (announcements.isEmpty) {
            return AdminEmptyView(
              title: 'No announcements yet',
              message: 'Create one to show a banner across the app.',
              icon: Icons.campaign_outlined,
              action: FilledButton(
                onPressed: () => _openEditor(),
                child: const Text('New announcement'),
              ),
            );
          }
          return Column(
            children: announcements.map((a) {
              final expired =
                  a.expiresAt != null && a.expiresAt!.isBefore(DateTime.now());
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _priorityColor(a.priority),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.title,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              if (!a.active)
                                AdminStatusChip.semantic(
                                  'Unpublished',
                                  tone: AdminTone.neutral,
                                )
                              else if (expired)
                                AdminStatusChip.semantic(
                                  'Expired',
                                  tone: AdminTone.warning,
                                )
                              else
                                AdminStatusChip.semantic(
                                  'Live',
                                  tone: AdminTone.good,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.body,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${a.audience.name} · ${RelativeTime.format(a.createdAt)}'
                            '${a.expiresAt != null ? ' · expires ${RelativeTime.format(a.expiresAt!)}' : ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: a.active ? 'Unpublish' : 'Publish',
                      onPressed: () => _toggleActive(a),
                      icon: Icon(
                        a.active
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => _openEditor(a),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: () => _delete(a),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _AnnouncementEditorDialog extends StatefulWidget {
  final Announcement? existing;
  const _AnnouncementEditorDialog({this.existing});

  @override
  State<_AnnouncementEditorDialog> createState() =>
      _AnnouncementEditorDialogState();
}

class _AnnouncementEditorDialogState extends State<_AnnouncementEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late AnnouncementPriority _priority;
  late AnnouncementAudience _audience;
  DateTime? _expiresAt;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _body = TextEditingController(text: widget.existing?.body ?? '');
    _priority = widget.existing?.priority ?? AnnouncementPriority.info;
    _audience = widget.existing?.audience ?? AnnouncementAudience.all;
    _expiresAt = widget.existing?.expiresAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final existing = widget.existing;
      if (existing == null) {
        await AnnouncementService.instance.create(
          title: _title.text.trim(),
          body: _body.text.trim(),
          priority: _priority,
          audience: _audience,
          adminId: AdminAuthService.instance.currentUid ?? 'unknown',
          expiresAt: _expiresAt,
        );
      } else {
        await AnnouncementService.instance.update(
          existing.copyWith(
            title: _title.text.trim(),
            body: _body.text.trim(),
            priority: _priority,
            audience: _audience,
            expiresAt: _expiresAt,
            clearExpiresAt: _expiresAt == null,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _saveError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'New announcement' : 'Edit announcement',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _body,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Body'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<AnnouncementPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: AnnouncementPriority.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                  .toList(),
              onChanged: (v) => setState(() => _priority = v ?? _priority),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<AnnouncementAudience>(
              initialValue: _audience,
              decoration: const InputDecoration(labelText: 'Audience'),
              items: AnnouncementAudience.values
                  .map((a) => DropdownMenuItem(value: a, child: Text(a.name)))
                  .toList(),
              onChanged: (v) => setState(() => _audience = v ?? _audience),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _expiresAt == null
                        ? 'No expiry — stays live until unpublished'
                        : 'Expires ${RelativeTime.format(_expiresAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _pickExpiry,
                  child: Text(_expiresAt == null ? 'Set expiry' : 'Change'),
                ),
                if (_expiresAt != null)
                  TextButton(
                    onPressed: () => setState(() => _expiresAt = null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            if (_saveError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _saveError!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
