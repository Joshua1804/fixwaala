import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatting.dart';
import '../../../features/ratings/models/rating_model.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_confirm_dialog.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import 'services/admin_moderation_service.dart';

/// Reputation is world-readable by design (see `firestore.rules`), so a
/// single abusive review is visible to every customer choosing a provider
/// until someone removes it. "Only low star ratings" surfaces what's worth
/// reviewing without paging through every 5-star review on the platform.
class AdminRatingsScreen extends StatefulWidget {
  const AdminRatingsScreen({super.key});

  @override
  State<AdminRatingsScreen> createState() => _AdminRatingsScreenState();
}

class _AdminRatingsScreenState extends State<AdminRatingsScreen> {
  bool _lowOnly = true;
  final List<fs.DocumentSnapshot<Map<String, dynamic>>?> _cursorStack = [null];
  int _pageIndex = 0;
  Future<RatingPage>? _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminModerationService.instance.fetchRatingPage(
      maxStars: _lowOnly ? 2 : null,
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

  Future<void> _delete(Rating rating) async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Delete rating',
      message:
          'This permanently removes a ${rating.stars}-star rating'
          '${rating.review != null ? ' and its review' : ''}. It cannot be '
          'undone, and the rater could leave a new one for the same job.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    await AdminModerationService.instance.deleteRating(rating);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Ratings',
      subtitle: 'Moderate reviews across the platform.',
      actions: [
        FilterChip(
          label: const Text('1–2 star only'),
          selected: _lowOnly,
          onSelected: (v) {
            setState(() => _lowOnly = v);
            _reset();
          },
        ),
      ],
      child: FutureBuilder<RatingPage>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AdminLoadingView();
          }
          if (snapshot.hasError) {
            return AdminErrorView(error: snapshot.error!, onRetry: _reset);
          }
          final page = snapshot.data!;
          if (page.ratings.isEmpty && _pageIndex == 0) {
            return AdminEmptyView(
              title: _lowOnly ? 'No low ratings' : 'No ratings yet',
              message: _lowOnly
                  ? 'Nothing rated 1 or 2 stars right now.'
                  : 'Ratings appear here once jobs are paid and rated.',
              icon: Icons.star_outline_rounded,
            );
          }
          return Column(
            children: [
              ...page.ratings.map((rating) => _RatingCard(
                rating: rating,
                busy: _busy,
                onDelete: () => _delete(rating),
              )),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _pageIndex == 0
                        ? null
                        : () => setState(() {
                            _pageIndex--;
                            _load();
                          }),
                    child: const Text('Previous'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: !page.hasMore
                        ? null
                        : () => setState(() {
                            if (_pageIndex + 1 >= _cursorStack.length) {
                              _cursorStack.add(page.lastDoc);
                            }
                            _pageIndex++;
                            _load();
                          }),
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final Rating rating;
  final bool busy;
  final VoidCallback onDelete;
  const _RatingCard({required this.rating, required this.busy, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating.stars ? Icons.star_rounded : Icons.star_border_rounded,
                size: 16,
                color: AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rating.review != null) Text(rating.review!),
                const SizedBox(height: 4),
                Text(
                  'Job ${rating.jobId} · ${RelativeTime.format(rating.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(
              AdminRouteNames.userDetail,
              arguments: rating.toUserId,
            ),
            child: const Text('Recipient'),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}
