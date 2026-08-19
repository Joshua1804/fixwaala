import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/widgets/mid_job_checkpoint.dart';

void main() {
  test('shows only when status is workInProgress', () {
    for (final status in JobStatus.values) {
      final result = shouldShowCheckpoint(
        status: status,
        jobId: 'job_1',
        alreadyShown: {},
      );
      expect(result, status == JobStatus.workInProgress);
    }
  });

  test('does not show twice for the same job', () {
    final shown = <String>{};
    expect(
      shouldShowCheckpoint(
        status: JobStatus.workInProgress,
        jobId: 'job_1',
        alreadyShown: shown,
      ),
      isTrue,
    );
    shown.add('job_1');
    expect(
      shouldShowCheckpoint(
        status: JobStatus.workInProgress,
        jobId: 'job_1',
        alreadyShown: shown,
      ),
      isFalse,
    );
  });

  test('a different job can still show its own checkpoint', () {
    final shown = {'job_1'};
    expect(
      shouldShowCheckpoint(
        status: JobStatus.workInProgress,
        jobId: 'job_2',
        alreadyShown: shown,
      ),
      isTrue,
    );
  });
}
