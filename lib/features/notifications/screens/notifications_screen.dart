import 'package:flutter/material.dart';

import '../../../core/models/announcement.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/announcement_feed_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/services/auth_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<AppUser?>(
        stream: AuthService.instance.currentUserStream,
        builder: (context, userSnap) {
          final role = userSnap.data?.role;
          if (role == null) {
            return const LoadingWidget(label: 'Loading...');
          }
          return StreamBuilder<List<Announcement>>(
            stream: AnnouncementFeedService.instance.watchFor(role),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const LoadingWidget(label: 'Loading notifications...');
              }
              final announcements = snap.data!;
              if (announcements.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  subtitle:
                      'Announcements from the Fixwaala team will show up here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: announcements.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _AnnouncementCard(announcement: announcements[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  const _AnnouncementCard({required this.announcement});

  Color get _accent => switch (announcement.priority) {
    AnnouncementPriority.critical => AppColors.error,
    AnnouncementPriority.warning => AppColors.warning,
    AnnouncementPriority.info => AppColors.info,
  };

  IconData get _icon => switch (announcement.priority) {
    AnnouncementPriority.critical => Icons.error_rounded,
    AnnouncementPriority.warning => Icons.warning_rounded,
    AnnouncementPriority.info => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _accent.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: _accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(announcement.title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text(announcement.body, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
