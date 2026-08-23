import {
  collection, doc, getDoc, getDocs, writeBatch, updateDoc,
  query, where, orderBy, startAfter, limit as fsLimit, Timestamp,
  type QueryDocumentSnapshot, type DocumentData,
} from 'firebase/firestore'
import { db } from '@/lib/firebase'
import { logAuditEvent } from './adminAuditService'
import { mapTicket, mapJob, type Ticket, type Job } from '@/types/models'
import type { TicketStatus, JobStatus } from '@/types/enums'

const ticketsCol = () => collection(db, 'tickets')
const openTicketsCol = () => collection(db, 'openTickets')
const jobsCol = () => collection(db, 'jobs')

export interface TicketPage {
  tickets: Ticket[]
  lastDoc: QueryDocumentSnapshot<DocumentData> | null
  hasMore: boolean
}

export interface JobPage {
  jobs: Job[]
  lastDoc: QueryDocumentSnapshot<DocumentData> | null
  hasMore: boolean
}

export async function fetchTicketPage(opts: {
  status?: TicketStatus
  startAfterDoc?: QueryDocumentSnapshot<DocumentData>
  pageLimit?: number
}): Promise<TicketPage> {
  const limitValue = opts.pageLimit ?? 25
  const constraints = []
  if (opts.status) constraints.push(where('status', '==', opts.status))
  constraints.push(orderBy('createdAt', 'desc'))
  if (opts.startAfterDoc) constraints.push(startAfter(opts.startAfterDoc))
  constraints.push(fsLimit(limitValue + 1))

  const snap = await getDocs(query(ticketsCol(), ...constraints))
  const docs = snap.docs
  const hasMore = docs.length > limitValue
  const pageDocs = hasMore ? docs.slice(0, limitValue) : docs
  return {
    tickets: pageDocs.map((d) => mapTicket(d.id, d.data())),
    lastDoc: pageDocs.length ? pageDocs[pageDocs.length - 1] : null,
    hasMore,
  }
}

export async function fetchTicket(id: string): Promise<Ticket | null> {
  const snap = await getDoc(doc(ticketsCol(), id))
  return snap.exists() ? mapTicket(snap.id, snap.data()) : null
}

/** The job created for ticketId, if any — a ticket only has one once a provider is confirmed. */
export async function fetchJobForTicket(ticketId: string): Promise<Job | null> {
  const snap = await getDocs(query(jobsCol(), where('ticketId', '==', ticketId), fsLimit(1)))
  return snap.empty ? null : mapJob(snap.docs[0]!.id, snap.docs[0]!.data())
}

/** Cancels a stuck ticket, removing its openTickets broadcast projection in the same batch. */
export async function forceCancelTicket(ticket: Ticket, reason: string): Promise<void> {
  const batch = writeBatch(db)
  batch.update(doc(ticketsCol(), ticket.id), {
    status: 'cancelled' satisfies TicketStatus,
    updatedAt: Timestamp.fromDate(new Date()),
  })
  batch.delete(doc(openTicketsCol(), ticket.id))
  await batch.commit()
  await logAuditEvent({
    action: 'ticket.force_cancel',
    targetType: 'ticket',
    targetId: ticket.id,
    details: { reason, previousStatus: ticket.status },
  })
}

export async function fetchJobPage(opts: {
  status?: JobStatus
  startAfterDoc?: QueryDocumentSnapshot<DocumentData>
  pageLimit?: number
}): Promise<JobPage> {
  const limitValue = opts.pageLimit ?? 25
  const constraints = []
  if (opts.status) constraints.push(where('status', '==', opts.status))
  constraints.push(orderBy('createdAt', 'desc'))
  if (opts.startAfterDoc) constraints.push(startAfter(opts.startAfterDoc))
  constraints.push(fsLimit(limitValue + 1))

  const snap = await getDocs(query(jobsCol(), ...constraints))
  const docs = snap.docs
  const hasMore = docs.length > limitValue
  const pageDocs = hasMore ? docs.slice(0, limitValue) : docs
  return {
    jobs: pageDocs.map((d) => mapJob(d.id, d.data())),
    lastDoc: pageDocs.length ? pageDocs[pageDocs.length - 1] : null,
    hasMore,
  }
}

export async function fetchJob(id: string): Promise<Job | null> {
  const snap = await getDoc(doc(jobsCol(), id))
  return snap.exists() ? mapJob(snap.id, snap.data()) : null
}

export async function forceCancelJob(job: Job, reason: string): Promise<void> {
  await updateDoc(doc(jobsCol(), job.jobId), {
    status: 'cancelled' satisfies JobStatus,
    cancellationReason: reason,
  })
  await logAuditEvent({
    action: 'job.force_cancel',
    targetType: 'job',
    targetId: job.jobId,
    details: { reason, previousStatus: job.status },
  })
}
