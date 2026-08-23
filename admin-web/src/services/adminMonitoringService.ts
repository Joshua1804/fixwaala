import { collection, getCountFromServer } from 'firebase/firestore'
import { db } from '@/lib/firebase'
import type { CollectionHealth } from '@/types/models'

/** Raw operational counts, distinct from the Dashboard's business-framed metrics — "is data flowing", not "how is the business doing". */
const monitoredCollections = [
  'users', 'tickets', 'openTickets', 'jobs', 'payments', 'ratings',
  'reports', 'safetyAlerts', 'deviceTokens', 'announcements', 'admins', 'auditEvents',
]

export async function loadCollectionHealth(): Promise<CollectionHealth[]> {
  const results = await Promise.all(
    monitoredCollections.map((name) => getCountFromServer(collection(db, name))),
  )
  return monitoredCollections.map((name, i) => ({ name, count: results[i]!.data().count }))
}
