import {
  collection,
  doc,
  serverTimestamp,
  setDoc,
  query,
  where,
  orderBy,
  limit as fsLimit,
  type Timestamp,
} from 'firebase/firestore'
import { db, auth } from '@/lib/firebase'

export interface AuditEvent {
  id: string
  actorAdminId: string
  actorAdminEmail: string
  action: string
  targetType: string
  targetId: string
  details: Record<string, unknown>
  createdAt: Date
}

function mapAuditEvent(id: string, data: Record<string, unknown>): AuditEvent {
  const createdAt = data.createdAt as Timestamp | undefined
  return {
    id,
    actorAdminId: (data.actorAdminId as string) ?? '',
    actorAdminEmail: (data.actorAdminEmail as string) ?? '',
    action: (data.action as string) ?? '',
    targetType: (data.targetType as string) ?? '',
    targetId: (data.targetId as string) ?? '',
    details: (data.details as Record<string, unknown>) ?? {},
    createdAt: createdAt ? createdAt.toDate() : new Date(),
  }
}

const auditCol = () => collection(db, 'auditEvents')

/** Writes an immutable audit event. Every mutating admin action calls this right after the write succeeds. */
export async function logAuditEvent(params: {
  action: string
  targetType: string
  targetId: string
  details?: Record<string, unknown>
}): Promise<void> {
  const docRef = doc(auditCol())
  await setDoc(docRef, {
    id: docRef.id,
    actorAdminId: auth.currentUser?.uid ?? 'unknown',
    actorAdminEmail: auth.currentUser?.email ?? 'unknown',
    action: params.action,
    targetType: params.targetType,
    targetId: params.targetId,
    details: params.details ?? {},
    createdAt: serverTimestamp(),
  })
}

/** Recent audit events, newest first, optionally filtered by actor or target type. */
export function auditEventsQuery(opts?: { actorAdminId?: string; targetType?: string; limit?: number }) {
  const limitValue = opts?.limit ?? 100
  if (opts?.actorAdminId) {
    return query(
      auditCol(),
      where('actorAdminId', '==', opts.actorAdminId),
      orderBy('createdAt', 'desc'),
      fsLimit(limitValue),
    )
  }
  if (opts?.targetType) {
    return query(
      auditCol(),
      where('targetType', '==', opts.targetType),
      orderBy('createdAt', 'desc'),
      fsLimit(limitValue),
    )
  }
  return query(auditCol(), orderBy('createdAt', 'desc'), fsLimit(limitValue))
}

export { mapAuditEvent }
