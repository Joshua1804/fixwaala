import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/report_model.dart';

/// Reports, Safety & Disputes (Module 11).
///
/// Reports and safety alerts are visible to the Admin Panel (Module 12) for
/// review and moderation. Severity/urgency is surfaced to admins, but
/// account restriction always remains an explicit admin decision — nothing
/// here auto-suspends anyone.
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final List<Report> _reports = [];
  final List<SafetyAlert> _safetyAlerts = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Emits whenever a report or safety alert is created or updated — the
  /// Admin Panel's Reports and Safety Alerts screens listen to this so new
  /// submissions (including SOS) appear without a manual refresh.
  Stream<void> get changes => _changes.stream;

  @visibleForTesting
  void resetForTesting() {
    _reports.clear();
    _safetyAlerts.clear();
  }

  Future<Report> submitReport({
    required String reporterId,
    required String reason,
    required String description,
    required ReportSeverity severity,
    List<String> evidenceUrls = const [],
    String? againstUserId,
    String? ticketId,
    String? jobId,
  }) async {
    if (description.trim().isEmpty) {
      throw ArgumentError('Please describe what happened.');
    }
    final report = Report(
      id: 'report-${DateTime.now().microsecondsSinceEpoch}',
      reporterId: reporterId,
      reason: reason,
      description: description.trim(),
      evidenceUrls: evidenceUrls,
      severity: severity,
      createdAt: DateTime.now(),
      againstUserId: againstUserId,
      ticketId: ticketId,
      jobId: jobId,
    );
    _reports.add(report);
    if (jobId != null) {
      await JobService.instance.flagReport(jobId);
    }
    _changes.add(null);
    return report;
  }

  Future<SafetyAlert> raiseSos({
    required String userId,
    String? ticketId,
    String? jobId,
  }) async {
    final alert = SafetyAlert(
      id: 'alert-${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      ticketId: ticketId,
      jobId: jobId,
      raisedAt: DateTime.now(),
    );
    _safetyAlerts.add(alert);
    if (jobId != null) {
      await JobService.instance.flagSafetyAlert(jobId);
    }
    _changes.add(null);
    return alert;
  }

  List<Report> allReports() {
    final list = List<Report>.from(_reports);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Report> openReports() => allReports()
      .where(
        (r) =>
            r.status == ReportStatus.open ||
            r.status == ReportStatus.underReview,
      )
      .toList();

  List<SafetyAlert> allSafetyAlerts() {
    final list = List<SafetyAlert>.from(_safetyAlerts);
    list.sort((a, b) => b.raisedAt.compareTo(a.raisedAt));
    return list;
  }

  List<SafetyAlert> unresolvedSafetyAlerts() =>
      allSafetyAlerts().where((a) => !a.resolved).toList();

  Future<void> updateReportStatus(
    String reportId,
    ReportStatus status, {
    String? adminId,
    String? note,
  }) async {
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index == -1) {
      throw ArgumentError('Report not found.');
    }
    final current = _reports[index];
    _reports[index] = current.copyWith(
      status: status,
      adminNote: note ?? current.adminNote,
      resolvedByAdminId:
          (status == ReportStatus.resolved || status == ReportStatus.rejected)
          ? adminId
          : current.resolvedByAdminId,
      updatedAt: DateTime.now(),
    );
    if (current.jobId != null &&
        (status == ReportStatus.resolved || status == ReportStatus.rejected)) {
      await JobService.instance.clearReportFlag(current.jobId!);
    }
    _changes.add(null);
  }

  Future<void> resolveSafetyAlert(
    String alertId, {
    required String adminId,
  }) async {
    final index = _safetyAlerts.indexWhere((a) => a.id == alertId);
    if (index == -1) {
      throw ArgumentError('Safety alert not found.');
    }
    _safetyAlerts[index] = _safetyAlerts[index].copyWith(
      resolved: true,
      resolvedByAdminId: adminId,
      resolvedAt: DateTime.now(),
    );
    _changes.add(null);
  }
}
