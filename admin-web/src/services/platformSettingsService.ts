import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore'
import { db } from '@/lib/firebase'
import { logAuditEvent } from './adminAuditService'
import { mapPlatformSettings, defaultPlatformSettings, type PlatformSettings } from '@/types/models'

/** platformSettings/config is a singleton — one document, one id, always read/written by that fixed reference. */
const settingsDoc = () => doc(db, 'platformSettings', 'config')

export async function fetchPlatformSettings(): Promise<PlatformSettings> {
  const snap = await getDoc(settingsDoc())
  if (!snap.exists()) return defaultPlatformSettings
  return mapPlatformSettings(snap.id, snap.data())
}

export async function savePlatformSettings(settings: PlatformSettings, adminId: string): Promise<void> {
  await setDoc(settingsDoc(), {
    maintenanceMode: settings.maintenanceMode,
    maintenanceMessage: settings.maintenanceMessage,
    supportEmail: settings.supportEmail,
    supportPhone: settings.supportPhone,
    searchRadiiKm: settings.searchRadiiKm,
    candidateReviewSeconds: settings.candidateReviewSeconds,
    minSupportedAppVersion: settings.minSupportedAppVersion,
    updatedAt: serverTimestamp(),
    updatedByAdminId: adminId,
  })
  await logAuditEvent({
    action: 'platform_settings.update',
    targetType: 'platformSettings',
    targetId: 'config',
    details: {
      maintenanceMode: settings.maintenanceMode,
      minSupportedAppVersion: settings.minSupportedAppVersion,
    },
  })
}
