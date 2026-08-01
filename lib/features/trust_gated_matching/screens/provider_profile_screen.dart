import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../auth/services/auth_service.dart';
import '../../provider_dashboard/models/analytics_model.dart';
import '../../provider_dashboard/services/analytics_service.dart';
import '../../provider_verification/services/verification_service.dart';
import '../../ratings/models/rating_model.dart';
import '../../ratings/services/rating_service.dart';

class _ProfileData {
  final AppUser? user;
  final VerificationStatus verification;
  final ProviderAnalytics analytics;
  final List<Rating> reviews;

  const _ProfileData({
    required this.user,
    required this.verification,
    required this.analytics,
    required this.reviews,
  });
}

/// Read-only public profile for a candidate provider, opened by a customer
/// from the review screen so they can check credentials, ratings, and past
/// reviews before confirming (Module 6 — Trust-Gated Matching).
class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  late Future<_ProfileData> _future;
  String? _providerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_providerId == null) {
      _providerId = ModalRoute.of(context)!.settings.arguments as String;
      _future = _load(_providerId!);
    }
  }

  Future<_ProfileData> _load(String providerId) async {
    final results = await Future.wait([
      AuthService.instance.getUserById(providerId),
      VerificationService.instance.status(providerId),
      AnalyticsService.instance.load(providerId),
    ]);
    return _ProfileData(
      user: results[0] as AppUser?,
      verification: results[1] as VerificationStatus,
      analytics: results[2] as ProviderAnalytics,
      reviews: RatingService.instance
          .ratingsFor(providerId)
          .where((r) => (r.review ?? '').trim().isNotEmpty)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provider profile')),
      body: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingWidget(label: 'Loading profile...');
          }
          final data = snapshot.data!;
          final user = data.user;
          final profile = user?.providerProfile;
          final analytics = data.analytics;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      _initials(user?.name ?? 'Provider'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Provider',
                          style: AppTextStyles.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        if (data.verification == VerificationStatus.approved)
                          const Row(
                            children: [
                              Icon(
                                Icons.verified,
                                size: 16,
                                color: AppColors.success,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Aadhaar + Selfie verified',
                                style: TextStyle(color: AppColors.success),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Not yet verified',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.star_rounded,
                      value: analytics.ratingCount == 0
                          ? '—'
                          : analytics.ratingAverage.toStringAsFixed(1),
                      label: analytics.ratingCount == 0
                          ? 'No ratings yet'
                          : '${analytics.ratingCount} ratings',
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.work_history_rounded,
                      value: '${analytics.completedJobs}',
                      label: 'Jobs done',
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.speed_rounded,
                      value: analytics.hasHistory
                          ? '${(analytics.completionRate * 100).toStringAsFixed(0)}%'
                          : '—',
                      label: 'Completion',
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Skills', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              if (profile == null || profile.skills.isEmpty)
                Text(
                  'No skills listed.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.skills
                      .map(
                        (s) => Chip(
                          avatar: Icon(
                            ServiceCategoryUi.icon(s),
                            size: 18,
                            color: AppColors.primary,
                          ),
                          label: Text(ServiceCategoryUi.label(s)),
                        ),
                      )
                      .toList(),
                ),
              if (profile?.experienceYears != null ||
                  profile?.serviceArea != null) ...[
                const SizedBox(height: 24),
                Text('Details', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                if (profile?.experienceYears != null)
                  _DetailRow(
                    icon: Icons.badge_outlined,
                    label: '${profile!.experienceYears} years experience',
                  ),
                if (profile?.serviceArea != null)
                  _DetailRow(
                    icon: Icons.map_outlined,
                    label: 'Serves ${profile!.serviceArea}',
                  ),
              ],
              const SizedBox(height: 24),
              Text(
                data.reviews.isEmpty
                    ? 'Reviews'
                    : 'Reviews (${data.reviews.length})',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: 8),
              if (data.reviews.isEmpty)
                Text(
                  'No written reviews yet.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                ...data.reviews.map((r) => _ReviewTile(rating: r)),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Rating rating;
  const _ReviewTile({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
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
          const SizedBox(height: 6),
          Text(rating.review!, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
