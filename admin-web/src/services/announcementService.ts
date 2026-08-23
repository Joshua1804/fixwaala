import { collection, doc, deleteDoc, setDoc, query, orderBy } from 'firebase/firestore'
import { db } from '@/lib/firebase'
import { logAuditEvent } from './adminAuditService'
import { mapAnnouncement, type Announcement } from '@/types/models'
import type { AnnouncementAudience, AnnouncementPriority } from '@/types/enums'

const announcementsCol = () => collection(db, 'announcements')

export function announcementsQuery() {
  return query(announcementsCol(), orderBy('createdAt', 'desc'))
}

export { mapAnnouncement }

export async function createAnnouncement(params: {
  title: string
  body: string
  priority: AnnouncementPriority
  audience: AnnouncementAudience
  adminId: string
  expiresAt?: Date
}): Promise<void> {
  const docRef = doc(announcementsCol())
  const announcement: Announcement = {
    id: docRef.id,
    title: params.title,
    body: params.body,
    active: true,
    priority: params.priority,
    audience: params.audience,
    createdAt: new Date(),
    createdByAdminId: params.adminId,
    expiresAt: params.expiresAt,
  }
  await setDoc(docRef, toFirestoreMap(announcement))
  await logAuditEvent({
    action: 'announcement.create',
    targetType: 'announcement',
    targetId: docRef.id,
    details: { title: params.title, priority: params.priority },
  })
}

export async function updateAnnouncement(announcement: Announcement): Promise<void> {
  const updated: Announcement = { ...announcement, updatedAt: new Date() }
  await setDoc(doc(announcementsCol(), announcement.id), toFirestoreMap(updated))
  await logAuditEvent({
    action: 'announcement.update',
    targetType: 'announcement',
    targetId: announcement.id,
    details: { title: updated.title, active: updated.active },
  })
}

export async function setAnnouncementActive(announcement: Announcement, active: boolean): Promise<void> {
  await updateAnnouncement({ ...announcement, active })
}

export async function deleteAnnouncement(announcement: Announcement): Promise<void> {
  await deleteDoc(doc(announcementsCol(), announcement.id))
  await logAuditEvent({
    action: 'announcement.delete',
    targetType: 'announcement',
    targetId: announcement.id,
    details: { title: announcement.title },
  })
}

function toFirestoreMap(a: Announcement) {
  return {
    id: a.id,
    title: a.title,
    body: a.body,
    active: a.active,
    priority: a.priority,
    audience: a.audience,
    createdAt: a.createdAt,
    ...(a.updatedAt ? { updatedAt: a.updatedAt } : {}),
    ...(a.expiresAt ? { expiresAt: a.expiresAt } : {}),
    createdByAdminId: a.createdByAdminId,
  }
}
