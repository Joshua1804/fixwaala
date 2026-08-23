import {
  collection, doc, getDoc, getDocs, deleteDoc, updateDoc,
  query, where, orderBy, startAfter, limit as fsLimit, Timestamp,
  type QueryDocumentSnapshot, type DocumentData,
} from 'firebase/firestore'
import { db } from '@/lib/firebase'
import { logAuditEvent } from './adminAuditService'
import { mapReport, mapSafetyAlert, mapRating, type Report, type Rating, type SafetyAlert } from '@/types/models'
import type { ReportStatus } from '@/types/enums'

const reportsCol = () => collection(db, 'reports')
const safetyAlertsCol = () => collection(db, 'safetyAlerts')
const ratingsCol = () => collection(db, 'ratings')

// ── Reports ──────────────────────────────────────────────────────────────

export interface ReportPage {
  reports: Report[]
  lastDoc: QueryDocumentSnapshot<DocumentData> | null
  hasMore: boolean
}

export async function fetchReportPage(opts: {
  status?: ReportStatus
  startAfterDoc?: QueryDocumentSnapshot<DocumentData>
  pageLimit?: number
}): Promise<ReportPage> {
  const limitValue = opts.pageLimit ?? 25
  const constraints = []
  if (opts.status) constraints.push(where('status', '==', opts.status))
  constraints.push(orderBy('createdAt', 'desc'))
  if (opts.startAfterDoc) constraints.push(startAfter(opts.startAfterDoc))
  constraints.push(fsLimit(limitValue + 1))

  const snap = await getDocs(query(reportsCol(), ...constraints))
  const docs = snap.docs
  const hasMore = docs.length > limitValue
  const pageDocs = hasMore ? docs.slice(0, limitValue) : docs
  return {
    reports: pageDocs.map((d) => mapReport(d.id, d.data())),
    lastDoc: pageDocs.length ? pageDocs[pageDocs.length - 1] : null,
    hasMore,
  }
}

export async function fetchReport(id: string): Promise<Report | null> {
  const snap = await getDoc(doc(reportsCol(), id))
  return snap.exists() ? mapReport(snap.id, snap.data()) : null
}

export async function resolveReport(
  report: Report,
  status: ReportStatus,
  adminNote: string,
  adminId: string,
): Promise<void> {
  await updateDoc(doc(reportsCol(), report.id), {
    status,
    adminNote,
    resolvedByAdminId: adminId,
    updatedAt: Timestamp.fromDate(new Date()),
  })
  // Lift the job's hasOpenReport flag once the report is settled, mirroring
  // the mobile app's (now-removed) JobService.clearReportFlag — otherwise a
  // resolved/rejected report leaves the job permanently flagged.
  if (report.jobId && (status === 'resolved' || status === 'rejected')) {
    await updateDoc(doc(collection(db, 'jobs'), report.jobId), {
      hasOpenReport: false,
    })
  }
  await logAuditEvent({
    action: 'report.resolve',
    targetType: 'report',
    targetId: report.id,
    details: { status, note: adminNote },
  })
}

// ── Safety alerts ────────────────────────────────────────────────────────

/** Live — an unresolved safety alert is urgent enough that pull-to-refresh pagination is the wrong fit. */
export function safetyAlertsQuery(resolved?: boolean) {
  const constraints = []
  if (resolved !== undefined) {
    constraints.push(where('resolved', '==', resolved), orderBy('raisedAt', 'desc'))
  } else {
    constraints.push(orderBy('raisedAt', 'desc'))
  }
  constraints.push(fsLimit(200))
  return query(safetyAlertsCol(), ...constraints)
}

export { mapSafetyAlert }

export async function fetchSafetyAlert(id: string): Promise<SafetyAlert | null> {
  const snap = await getDoc(doc(safetyAlertsCol(), id))
  return snap.exists() ? mapSafetyAlert(snap.id, snap.data()) : null
}

export async function resolveSafetyAlert(alertId: string, adminId: string): Promise<void> {
  await updateDoc(doc(safetyAlertsCol(), alertId), {
    resolved: true,
    resolvedByAdminId: adminId,
    resolvedAt: Timestamp.fromDate(new Date()),
  })
  await logAuditEvent({
    action: 'safety_alert.resolve',
    targetType: 'safetyAlert',
    targetId: alertId,
    details: {},
  })
}

// ── Ratings ──────────────────────────────────────────────────────────────

export interface RatingPage {
  ratings: Rating[]
  lastDoc: QueryDocumentSnapshot<DocumentData> | null
  hasMore: boolean
}

/** stars <= maxStars combined with orderBy(createdAt) would need an undeclared composite index — order by stars instead, needing only the automatic single-field index. */
export async function fetchRatingPage(opts: {
  maxStars?: number
  startAfterDoc?: QueryDocumentSnapshot<DocumentData>
  pageLimit?: number
}): Promise<RatingPage> {
  const limitValue = opts.pageLimit ?? 25
  const constraints = []
  if (opts.maxStars !== undefined) {
    constraints.push(where('stars', '<=', opts.maxStars), orderBy('stars'), orderBy('createdAt', 'desc'))
  } else {
    constraints.push(orderBy('createdAt', 'desc'))
  }
  if (opts.startAfterDoc) constraints.push(startAfter(opts.startAfterDoc))
  constraints.push(fsLimit(limitValue + 1))

  const snap = await getDocs(query(ratingsCol(), ...constraints))
  const docs = snap.docs
  const hasMore = docs.length > limitValue
  const pageDocs = hasMore ? docs.slice(0, limitValue) : docs
  return {
    ratings: pageDocs.map((d) => mapRating(d.id, d.data())),
    lastDoc: pageDocs.length ? pageDocs[pageDocs.length - 1] : null,
    hasMore,
  }
}

export async function deleteRating(rating: Pick<Rating, 'id' | 'jobId' | 'stars'>): Promise<void> {
  await deleteDoc(doc(ratingsCol(), rating.id))
  await logAuditEvent({
    action: 'rating.delete',
    targetType: 'rating',
    targetId: rating.id,
    details: { jobId: rating.jobId, stars: rating.stars },
  })
}
