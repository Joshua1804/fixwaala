import {
  collection, doc, getDoc, getDocs, updateDoc,
  query, where, orderBy, startAfter, limit as fsLimit, Timestamp,
  type QueryDocumentSnapshot, type DocumentData,
} from 'firebase/firestore'
import { db } from '@/lib/firebase'
import { logAuditEvent } from './adminAuditService'
import { mapPayment, type PaymentRecord, type PaymentDisputeStatus } from '@/types/models'
import type { PaymentStatus } from '@/types/enums'

const paymentsCol = () => collection(db, 'payments')

export interface PaymentPage {
  payments: PaymentRecord[]
  lastDoc: QueryDocumentSnapshot<DocumentData> | null
  hasMore: boolean
}

/** Rules-driven index choice: disputeStatus and status each have their own composite with processedAt, not combined — one filter at a time. */
export async function fetchPaymentPage(opts: {
  status?: PaymentStatus
  disputeStatus?: PaymentDisputeStatus
  startAfterDoc?: QueryDocumentSnapshot<DocumentData>
  pageLimit?: number
}): Promise<PaymentPage> {
  const limitValue = opts.pageLimit ?? 25
  const constraints = []
  if (opts.disputeStatus) {
    constraints.push(where('disputeStatus', '==', opts.disputeStatus))
  } else if (opts.status) {
    constraints.push(where('status', '==', opts.status))
  }
  constraints.push(orderBy('processedAt', 'desc'))
  if (opts.startAfterDoc) constraints.push(startAfter(opts.startAfterDoc))
  constraints.push(fsLimit(limitValue + 1))

  const snap = await getDocs(query(paymentsCol(), ...constraints))
  const docs = snap.docs
  const hasMore = docs.length > limitValue
  const pageDocs = hasMore ? docs.slice(0, limitValue) : docs
  return {
    payments: pageDocs.map((d) => mapPayment(d.id, d.data())),
    lastDoc: pageDocs.length ? pageDocs[pageDocs.length - 1] : null,
    hasMore,
  }
}

export async function fetchPayment(id: string): Promise<PaymentRecord | null> {
  const snap = await getDoc(doc(paymentsCol(), id))
  return snap.exists() ? mapPayment(snap.id, snap.data()) : null
}

export async function setPaymentDispute(
  payment: PaymentRecord,
  status: PaymentDisputeStatus,
  note: string,
  adminId: string,
): Promise<void> {
  await updateDoc(doc(paymentsCol(), payment.id), {
    disputeStatus: status,
    disputeNote: note,
    disputeUpdatedAt: Timestamp.fromDate(new Date()),
    disputeUpdatedByAdminId: adminId,
  })
  await logAuditEvent({
    action: 'payment.set_dispute',
    targetType: 'payment',
    targetId: payment.id,
    details: { status, note },
  })
}
