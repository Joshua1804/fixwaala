import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';

/// Central place for how a [JobStatus] is labelled, colored, and iconed.
///
/// Reused by the customer Job Tracking screen, the provider Active Jobs /
/// Job Details / Status Update screens, and the admin Active Tickets screen
/// so the lifecycle reads identically everywhere.
class JobStatusUi {
  JobStatusUi._();

  /// Ordered forward path through the lifecycle, used to render a stepper.
  /// [JobStatus.cancelled] is a terminal side-state and is not part of it.
  static const List<JobStatus> timelineOrder = [
    JobStatus.assigned,
    JobStatus.accepted,
    JobStatus.enRoute,
    JobStatus.arrived,
    JobStatus.checkedIn,
    JobStatus.inspecting,
    JobStatus.estimateSubmitted,
    JobStatus.workInProgress,
    JobStatus.completionRequested,
    JobStatus.completed,
  ];

  static String label(JobStatus status) => switch (status) {
    JobStatus.assigned => 'Assigned',
    JobStatus.accepted => 'Accepted',
    JobStatus.enRoute => 'En Route',
    JobStatus.arrived => 'Arrived',
    JobStatus.checkedIn => 'Checked In',
    JobStatus.inspecting => 'Inspecting',
    JobStatus.estimateSubmitted => 'Estimate Submitted',
    JobStatus.workInProgress => 'Work In Progress',
    JobStatus.completionRequested => 'Completion Requested',
    JobStatus.completed => 'Completed',
    JobStatus.cancelled => 'Cancelled',
  };

  static String customerMessage(JobStatus status) => switch (status) {
    JobStatus.assigned => 'Your provider has been assigned and notified.',
    JobStatus.accepted =>
      'Your provider accepted the job and is getting ready.',
    JobStatus.enRoute => 'Your provider is on the way.',
    JobStatus.arrived => 'Your provider has arrived at your location.',
    JobStatus.checkedIn => 'Your provider has checked in.',
    JobStatus.inspecting => 'Your provider is inspecting the issue.',
    JobStatus.estimateSubmitted =>
      'A repair estimate is ready for your review.',
    JobStatus.workInProgress => 'Repair work is in progress.',
    JobStatus.completionRequested =>
      'Your provider marked the job complete — please confirm.',
    JobStatus.completed => 'Job completed. Continue to payment.',
    JobStatus.cancelled => 'This job was cancelled.',
  };

  static Color color(JobStatus status) => switch (status) {
    JobStatus.assigned => AppColors.info,
    JobStatus.accepted => AppColors.info,
    JobStatus.enRoute => AppColors.accent,
    JobStatus.arrived => AppColors.accent,
    JobStatus.checkedIn => AppColors.primary,
    JobStatus.inspecting => AppColors.primary,
    JobStatus.estimateSubmitted => AppColors.warning,
    JobStatus.workInProgress => AppColors.primaryLight,
    JobStatus.completionRequested => AppColors.warning,
    JobStatus.completed => AppColors.success,
    JobStatus.cancelled => AppColors.error,
  };

  static IconData icon(JobStatus status) => switch (status) {
    JobStatus.assigned => Icons.assignment_ind_rounded,
    JobStatus.accepted => Icons.thumb_up_rounded,
    JobStatus.enRoute => Icons.directions_car_rounded,
    JobStatus.arrived => Icons.location_on_rounded,
    JobStatus.checkedIn => Icons.how_to_reg_rounded,
    JobStatus.inspecting => Icons.search_rounded,
    JobStatus.estimateSubmitted => Icons.receipt_long_rounded,
    JobStatus.workInProgress => Icons.build_rounded,
    JobStatus.completionRequested => Icons.task_alt_rounded,
    JobStatus.completed => Icons.check_circle_rounded,
    JobStatus.cancelled => Icons.cancel_rounded,
  };

  /// Label for the primary provider action button that moves the job to the
  /// next step, or null if the provider has no forward action right now
  /// (e.g. waiting on the customer).
  static String? providerActionLabel(JobStatus status) => switch (status) {
    JobStatus.assigned => 'Accept job',
    JobStatus.accepted => 'Start travel (En Route)',
    JobStatus.enRoute => 'Mark arrived',
    JobStatus.arrived => 'Check in',
    JobStatus.checkedIn => 'Start inspection',
    JobStatus.inspecting => 'Enter diagnosis & estimate',
    JobStatus.workInProgress => 'Request completion',
    _ => null,
  };
}

/// A compact vertical stepper visualising progress through [JobStatusUi.timelineOrder].
class JobStatusStepper extends StatelessWidget {
  final JobStatus current;

  const JobStatusStepper({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    if (current == JobStatus.cancelled) {
      return _CancelledBanner();
    }
    final currentIndex = JobStatusUi.timelineOrder.indexOf(current);
    return Column(
      children: [
        for (var i = 0; i < JobStatusUi.timelineOrder.length; i++)
          _StepRow(
            status: JobStatusUi.timelineOrder[i],
            state: i < currentIndex
                ? _StepState.done
                : i == currentIndex
                ? _StepState.current
                : _StepState.upcoming,
            isLast: i == JobStatusUi.timelineOrder.length - 1,
          ),
      ],
    );
  }
}

enum _StepState { done, current, upcoming }

class _StepRow extends StatelessWidget {
  final JobStatus status;
  final _StepState state;
  final bool isLast;

  const _StepRow({
    required this.status,
    required this.state,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.current => JobStatusUi.color(status),
      _StepState.upcoming => AppColors.textHint.withValues(alpha: 0.4),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: state == _StepState.upcoming
                      ? Colors.transparent
                      : color.withValues(alpha: 0.15),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  state == _StepState.done
                      ? Icons.check_rounded
                      : JobStatusUi.icon(status),
                  size: 15,
                  color: color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: state == _StepState.done
                        ? AppColors.success
                        : AppColors.textHint.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                JobStatusUi.label(status),
                style: TextStyle(
                  fontWeight: state == _StepState.current
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: state == _StepState.upcoming
                      ? AppColors.textHint
                      : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This job was cancelled.',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
