import { collection, query as fsQuery } from 'firebase/firestore'
import { db } from '@/lib/firebase'
import { mapAdminDirectoryEntry } from '@/types/models'

/** Read-only view of admins/{uid}. Nothing here can write it — that's scripts/admin/grant_admin_claim.js. */
export function adminDirectoryQuery() {
  return fsQuery(collection(db, 'admins'))
}

export { mapAdminDirectoryEntry }
