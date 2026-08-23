import {
  collection, doc, getDoc, getDocs, deleteDoc, updateDoc,
  query, where, orderBy, startAt, endAt, startAfter, limit as fsLimit,
  type QueryDocumentSnapshot, type DocumentData,
} from 'firebase/firestore'
import { db } from '@/lib/firebase'
import { logAuditEvent } from './adminAuditService'
import { mapAppUser, type AppUser } from '@/types/models'
import type { AccountStatus, UserRole } from '@/types/enums'

const usersCol = () => collection(db, 'users')
const publicProfilesCol = () => collection(db, 'providerPublicProfiles')

export interface UserPage {
  users: AppUser[]
  lastDoc: QueryDocumentSnapshot<DocumentData> | null
  hasMore: boolean
}

/** Browse, filtered by role and/or account status, newest first. Status is only honored when a role is also chosen (mirrors the index constraint in AdminUserService.fetchPage). */
export async function fetchUserPage(opts: {
  role?: UserRole
  status?: AccountStatus
  startAfterDoc?: QueryDocumentSnapshot<DocumentData>
  pageLimit?: number
}): Promise<UserPage> {
  const limitValue = opts.pageLimit ?? 25
  const constraints = []
  if (opts.role) {
    constraints.push(where('role', '==', opts.role))
    if (opts.status) constraints.push(where('accountStatus', '==', opts.status))
  }
  constraints.push(orderBy('createdAt', 'desc'))
  if (opts.startAfterDoc) constraints.push(startAfter(opts.startAfterDoc))
  constraints.push(fsLimit(limitValue + 1))

  const snap = await getDocs(query(usersCol(), ...constraints))
  const docs = snap.docs
  const hasMore = docs.length > limitValue
  const pageDocs = hasMore ? docs.slice(0, limitValue) : docs
  return {
    users: pageDocs.map((d) => mapAppUser(d.id, d.data())),
    lastDoc: pageDocs.length ? pageDocs[pageDocs.length - 1] : null,
    hasMore,
  }
}

/** Exact-email or name-prefix search — the honest boundary of a single-field Firestore query without a third-party index. */
export async function searchUsers(term: string): Promise<AppUser[]> {
  const trimmed = term.trim()
  if (!trimmed) return []
  if (trimmed.includes('@')) {
    const snap = await getDocs(query(usersCol(), where('email', '==', trimmed.toLowerCase()), fsLimit(20)))
    return snap.docs.map((d) => mapAppUser(d.id, d.data()))
  }
  // Standard Firestore prefix-range trick: end the range at the term with a
  // high sentinel codepoint appended so it sorts after every string that
  // starts with the term.
  const snap = await getDocs(
    query(usersCol(), orderBy('name'), startAt(trimmed), endAt(trimmed + ''), fsLimit(20)),
  )
  return snap.docs.map((d) => mapAppUser(d.id, d.data()))
}

export async function fetchUser(userId: string): Promise<AppUser | null> {
  const snap = await getDoc(doc(usersCol(), userId))
  return snap.exists() ? mapAppUser(snap.id, snap.data()) : null
}

/** Editable-by-admin fields only, deliberately smaller than firestore.rules technically allows. */
export async function updateUserProfile(user: AppUser, fields: { name?: string; phone?: string }): Promise<void> {
  await updateDoc(doc(usersCol(), user.id), {
    ...(fields.name !== undefined ? { name: fields.name } : {}),
    ...(fields.phone !== undefined ? { phone: fields.phone } : {}),
    updatedAt: new Date().toISOString(),
  })
  await logAuditEvent({
    action: 'user.update_profile',
    targetType: 'user',
    targetId: user.id,
    details: fields,
  })
}

export async function setUserAccountStatus(user: AppUser, status: AccountStatus, reason: string): Promise<void> {
  await updateDoc(doc(usersCol(), user.id), {
    accountStatus: status,
    updatedAt: new Date().toISOString(),
  })
  await logAuditEvent({
    action: 'user.set_account_status',
    targetType: 'user',
    targetId: user.id,
    details: { status, reason, email: user.email },
  })
}

/** Grants/revokes the Verified badge; the provider's own device republishes providerPublicProfiles on next launch. */
export async function setUserVerified(user: AppUser, verified: boolean): Promise<void> {
  await updateDoc(doc(usersCol(), user.id), {
    isVerified: verified,
    updatedAt: new Date().toISOString(),
  })
  await logAuditEvent({
    action: verified ? 'user.verify' : 'user.unverify',
    targetType: 'user',
    targetId: user.id,
    details: { email: user.email },
  })
}

/** Deletes the Firestore profile only — cannot delete the Firebase Auth account (needs the Admin SDK). Run scripts/admin/delete_user.js afterwards. */
export async function deleteUserProfile(user: AppUser): Promise<void> {
  await deleteDoc(doc(usersCol(), user.id))
  if (user.role === 'provider') {
    try {
      await deleteDoc(doc(publicProfilesCol(), user.id))
    } catch {
      // best-effort, mirrors the Dart .catchError((_) {})
    }
  }
  await logAuditEvent({
    action: 'user.delete_profile',
    targetType: 'user',
    targetId: user.id,
    details: { email: user.email, role: user.role },
  })
}
