import '../../../core/models/enums.dart';
import '../models/job_model.dart';

class JobService {
  JobService._();
  static final JobService instance = JobService._();

  Future<void> emitEvent(String jobId, JobEvent event) async {
    // TODO: append to job event log + transition ticket status.
  }

  Future<void> submitEstimate(String jobId, RepairEstimate estimate) async {
    // TODO
  }

  Future<void> approveEstimate(String jobId) async {
    // TODO
  }

  Future<void> rejectEstimate(String jobId) async {
    // TODO
  }

  Future<void> markCompleted(String jobId) async {
    // TODO
  }

  Stream<Job> watchJob(String jobId) async* {
    // TODO: Firestore stream.
  }
}
