import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatting.dart';
import '../../../features/customer_ticket/models/ticket_model.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_pagination_bar.dart';
import '../../widgets/admin_state_views.dart';
import '../tickets_jobs/services/admin_ticket_job_service.dart';

/// Browses photos attached to customer tickets — the only media Fixwaala
/// stores. There is no Firebase Storage bucket in this app (see
/// `docs/CONFIGURATION.md`); photos live on Cloudinary, referenced by URL
/// from `tickets/{id}.imageUrls`. That is also this screen's ceiling:
/// listing/deleting the underlying Cloudinary assets directly needs a
/// signed request with Cloudinary's API secret, which — like the Gemini key
/// before it — must never be compiled into a client. Full asset management
/// would need a small server endpoint; this screen shows what's already
/// reachable through Firestore, which is everything an admin needs to
/// investigate a specific ticket's photos.
class AdminMediaScreen extends StatefulWidget {
  const AdminMediaScreen({super.key});

  @override
  State<AdminMediaScreen> createState() => _AdminMediaScreenState();
}

class _AdminMediaScreenState extends State<AdminMediaScreen> {
  final List<fs.DocumentSnapshot<Map<String, dynamic>>?> _cursorStack = [null];
  int _pageIndex = 0;
  Future<TicketPage>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminTicketJobService.instance.fetchTicketPage(
      startAfter: _cursorStack[_pageIndex],
      limit: 40,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Media',
      subtitle: 'Photos attached to customer tickets, newest tickets first.',
      child: FutureBuilder<TicketPage>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AdminLoadingView();
          }
          if (snapshot.hasError) {
            return AdminErrorView(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          }
          final page = snapshot.data!;
          final withPhotos = page.tickets.where((t) => t.imageUrls.isNotEmpty).toList();
          if (withPhotos.isEmpty) {
            return Column(
              children: [
                const AdminEmptyView(
                  title: 'No photos on this page',
                  message: 'These tickets in this range had no photos attached.',
                  icon: Icons.photo_library_outlined,
                ),
                _pager(page),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...withPhotos.map((ticket) => _TicketPhotoRow(ticket: ticket)),
              _pager(page),
            ],
          );
        },
      ),
    );
  }

  Widget _pager(TicketPage page) {
    return AdminPaginationBar(
      pageNumber: _pageIndex + 1,
      pageSize: 40,
      currentCount: page.tickets.length,
      hasPrevious: _pageIndex > 0,
      hasNext: page.hasMore,
      isLoading: false,
      onPrevious: _pageIndex == 0
          ? null
          : () => setState(() {
              _pageIndex--;
              _load();
            }),
      onNext: () => setState(() {
        if (_pageIndex + 1 >= _cursorStack.length) {
          _cursorStack.add(page.lastDoc);
        }
        _pageIndex++;
        _load();
      }),
    );
  }
}

class _TicketPhotoRow extends StatelessWidget {
  final Ticket ticket;
  const _TicketPhotoRow({required this.ticket});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.customerName.isNotEmpty
                      ? ticket.customerName
                      : ticket.customerFirstName,
                  style: AppTextStyles.titleSmall,
                ),
              ),
              Text(
                RelativeTime.format(ticket.createdAt),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed(
                  AdminRouteNames.ticketDetail,
                  arguments: ticket.id,
                ),
                child: const Text('Open ticket'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: ticket.imageUrls.map((url) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  url,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    width: 96,
                    height: 96,
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
      ),
    );
  }
}
