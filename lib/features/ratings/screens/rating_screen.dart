import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/services/auth_service.dart';
import '../services/rating_service.dart';
import '../../../core/utils/error_messages.dart';

/// Rating and Review Screen (Module 9).
///
/// One rating per (job, rater) pair is enforced by [RatingService] — if the
/// current user already rated this job, that is shown instead of the form.
class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0;
  final _reviewController = TextEditingController();
  bool _submitting = false;
  String? _error;

  Map<String, dynamic> _args(BuildContext context) =>
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
      const {};

  /// Where this user belongs after rating.
  ///
  /// Both exits used to be hardcoded to [RouteNames.customerHome], so a
  /// provider who rated a customer had their entire navigation stack replaced
  /// with the customer app — and `pushNamedAndRemoveUntil` left them no way
  /// back.
  String _homeRouteFor(AppUser user) => user.role == UserRole.provider
      ? RouteNames.providerHome
      : RouteNames.customerHome;

  Future<void> _submit(AppUser me, Map<String, dynamic> args) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await RatingService.instance.submit(
        jobId: args['jobId'] as String,
        fromUserId: me.id,
        toUserId: args['toUserId'] as String,
        direction:
            args['direction'] as RatingDirection? ??
            RatingDirection.customerToProvider,
        stars: _stars,
        review: _reviewController.text,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(_homeRouteFor(me), (route) => false);
    } catch (e) {
      setState(() => _error = ErrorMessages.friendly(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args(context);
    final toName = args['toName'] as String? ?? 'your provider';
    final jobId = args['jobId'] as String?;

    return Scaffold(
      appBar: AppBar(title: Text('Rate $toName')),
      body: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingWidget();
          }
          final me = snapshot.data;
          if (me == null || jobId == null) {
            return const Center(child: Text('Unable to load rating details.'));
          }

          final alreadyRated = RatingService.instance.hasRated(
            jobId: jobId,
            fromUserId: me.id,
          );
          if (alreadyRated) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 56,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You already rated this job.',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Back to home',
                    onPressed: () =>
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          _homeRouteFor(me),
                          (route) => false,
                        ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How was your experience with $toName?',
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                // A screen reader previously announced five identical,
                // unlabelled buttons here, with no way to tell which was
                // selected or what tapping one would do.
                Semantics(
                  container: true,
                  label: 'Rating',
                  value: '$_stars out of 5 stars',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final value = i + 1;
                      return IconButton(
                        iconSize: 40,
                        tooltip: '$value star${value == 1 ? '' : 's'}',
                        onPressed: () => setState(() => _stars = value),
                        icon: Semantics(
                          selected: value <= _stars,
                          child: Icon(
                            i < _stars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppColors.accent,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _reviewController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Leave a review (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const Spacer(),
                PrimaryButton(
                  label: 'Submit rating',
                  loading: _submitting,
                  onPressed: _stars == 0 ? null : () => _submit(me, args),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
