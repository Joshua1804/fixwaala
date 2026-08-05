import 'package:flutter/material.dart';

import '../../../core/models/provider_public_profile.dart';
import '../../../core/services/provider_directory_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../ratings/models/rating_model.dart';
import '../../ratings/services/rating_service.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/missing_route_argument_screen.dart';

class _ProfileData {
  final ProviderPublicProfile? user;

  /// Every rating this provider has received. Reputation is deliberately
  /// world-readable; the aggregates below are derived from it rather than
  /// from a stored counter the provider could inflate.
  final List<Rating> ratings;

  const _ProfileData({required this.user, required this.ratings});

  int get ratingCount => ratings.length;

  double get ratingAverage => ratings.isEmpty
      ? 0
      : ratings.map((r) => r.stars).reduce((a, b) => a + b) / ratings.length;

  List<Rating> get reviews =>
      ratings.where((r) => (r.review ?? '').trim().isNotEmpty).toList();
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
      _providerId = ModalRoute.of(context)?.settings.arguments as String? ?? '';
      _future = _load(_providerId!);
    }
  }

  /// Loads only what a customer is entitled to see about a provider.
  ///
  /// Both sources are public by design. The identity half comes from
  /// `providerPublicProfiles`, not `users/{uid}` — that document carries the
  /// provider's phone, address, and live GPS, and the rules make it readable
  /// by its owner alone.
  ///
  /// This deliberately does **not** go through [AnalyticsService], which
  /// derives its numbers from the local job cache. That cache now holds only
  /// the signed-in user's own jobs, so asking it about someone else returns
  /// zeros — and reading another provider's jobs is exactly what the rules
  /// forbid. Public reputation comes from the ratings collection instead.
  Future<_ProfileData> _load(String providerId) async {
    final results = await Future.wait([
      ProviderDirectoryService.instance.fetch(providerId),
      RatingService.instance.fetchRatingsFor(providerId),
    ]);
    return _ProfileData(
      user: results[0] as ProviderPublicProfile?,
      ratings: results[1] as List<Rating>,
    );
  }

  @override
  Widget build(BuildContext context) {
    if ((_providerId ?? '').isEmpty) {
      return const MissingRouteArgumentScreen(title: 'Provider profile');
    }
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

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      initialsOf(user?.name ?? 'Provider'),
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
                        if (user?.isVerified ?? false)
                          const Row(
                            children: [
                              Icon(
                                Icons.verified,
                                size: 16,
                                color: AppColors.success,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verified',
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
              // Only stats a customer is entitled to verify. Job counts and
              // completion rates come from the provider's private job history
              // and stay on their own dashboard.
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.star_rounded,
                      value: data.ratingCount == 0
                          ? '—'
                          : data.ratingAverage.toStringAsFixed(1),
                      label: data.ratingCount == 0
                          ? 'No ratings yet'
                          : 'Average rating',
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.reviews_rounded,
                      value: '${data.ratingCount}',
                      label: data.ratingCount == 1 ? 'Rated job' : 'Rated jobs',
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.event_available_rounded,
                      value: user?.createdAt.year.toString() ?? '—',
                      label: 'Member since',
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Skills', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              if (user == null || user.skills.isEmpty)
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
                  children: user.skills
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
              if (user?.experienceYears != null ||
                  user?.serviceArea != null) ...[
                const SizedBox(height: 24),
                Text('Details', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                if (user?.experienceYears != null)
                  _DetailRow(
                    icon: Icons.badge_outlined,
                    label: '${user!.experienceYears} years experience',
                  ),
                if (user?.serviceArea != null)
                  _DetailRow(
                    icon: Icons.map_outlined,
                    label: 'Serves ${user!.serviceArea}',
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
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
                i < rating.stars
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
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
