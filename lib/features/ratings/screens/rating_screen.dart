import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/widgets/custom_button.dart';
import '../models/rating_model.dart';
import '../services/rating_service.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _stars = 0;
  final _reviewController = TextEditingController();
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await RatingService.instance.submit(
      Rating(
        id: 'rating-${DateTime.now().microsecondsSinceEpoch}',
        jobId: 'job-id-stub',
        fromUserId: 'current-user-id',
        toUserId: 'target-user-id',
        stars: _stars,
        review: _reviewController.text.trim().isEmpty
            ? null
            : _reviewController.text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pushNamedAndRemoveUntil(
      RouteNames.customerHome,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your provider')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => IconButton(
                  iconSize: 40,
                  onPressed: () => setState(() => _stars = i + 1),
                  icon: Icon(
                    i < _stars ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                ),
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
            const Spacer(),
            PrimaryButton(
              label: 'Submit rating',
              loading: _submitting,
              onPressed: _stars == 0 ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
