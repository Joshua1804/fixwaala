import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/services/firebase_service.dart';
import '../../../core/admin_audit_service.dart';
import '../models/platform_settings.dart';

/// `platformSettings/config` is a singleton — one document, one id, always
/// read/written by that fixed reference.
class PlatformSettingsService {
  PlatformSettingsService._();
  static final PlatformSettingsService instance = PlatformSettingsService._();

  fs.DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseService.instance.firestore.collection('platformSettings').doc('config');

  Future<PlatformSettings> fetch() async {
    final snap = await _doc.get();
    if (!snap.exists || snap.data() == null) return const PlatformSettings();
    return PlatformSettings.fromMap(snap.data()!);
  }

  Future<void> save(PlatformSettings settings, {required String adminId}) async {
    final updated = settings.copyWith(updatedByAdminId: adminId);
    await _doc.set(updated.toMap());
    await AdminAuditService.instance.log(
      action: 'platform_settings.update',
      targetType: 'platformSettings',
      targetId: 'config',
      details: {
        'maintenanceMode': updated.maintenanceMode,
        'minSupportedAppVersion': updated.minSupportedAppVersion,
      },
    );
  }
}
