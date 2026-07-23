import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../service_lifecycle/models/job_model.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../services/analytics_service.dart';
import '../services/trust_score_calculator.dart';

/// Rating and Trust Score Screen — shows the provider's overall Trust
/// Score, computed from ratings, completion rate, response time, and
/// cancellations (see [TrustScoreCalculator]).
class TrustScoreScreen extends StatelessWidget {
  const TrustScoreScreen({super.key});

  // NOTE: uses a shared demo provider id — see AppConstants.demoProviderId.
  String get _providerId => AppConstants.demoProviderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trust score')),
      body: StreamBuilder<Job>(
        stream: JobService.instance.watchAllChanges(),
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return FutureBuilder<TrustScoreResult>(
      future: AnalyticsService.instance.trustScore(_providerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingWidget(label: 'Calculating your trust score...');
        }
        final result = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              if (result.hasScore) ...[
                _ScoreDial(score: result.score!),
                const SizedBox(height: 20),
                Text(
                  result.note,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
              ] else ...[
                Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: AppColors.textHint.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'Not enough data yet',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.note,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ],
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How this is calculated',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _WeightRow(
                        label: 'Customer ratings',
                        weight: AppConstants.trustWeightRating,
                      ),
                      _WeightRow(
                        label: 'Completion rate',
                        weight: AppConstants.trustWeightCompletion,
                      ),
                      _WeightRow(
                        label: 'Response speed',
                        weight: AppConstants.trustWeightResponse,
                      ),
                      _WeightRow(
                        label: 'Low cancellations',
                        weight: AppConstants.trustWeightCancellation,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreDial extends StatelessWidget {
  final double score;
  const _ScoreDial({required this.score});

  Color get _color {
    if (score >= 85) return AppColors.success;
    if (score >= 70) return AppColors.primary;
    if (score >= 50) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 10,
              backgroundColor: AppColors.divider.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: AppTextStyles.displayMedium.copyWith(color: _color),
              ),
              Text(
                '/ 100',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  final String label;
  final double weight;
  const _WeightRow({required this.label, required this.weight});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(
            '${(weight * 100).toStringAsFixed(0)}%',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}
