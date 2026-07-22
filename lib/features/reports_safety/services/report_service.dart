import '../models/report_model.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  Future<String> submitReport(Report report) async {
    // TODO:
    //   • persist report doc
    //   • if severity == high, temporarily restrict target account
    //   • push to admin dashboard queue
    return 'report-id-stub';
  }

  Future<void> raiseSos(SafetyAlert alert) async {
    // TODO:
    //   • create safety_alert doc
    //   • flag the active ticket
    //   • notify admin dashboard immediately
  }
}
