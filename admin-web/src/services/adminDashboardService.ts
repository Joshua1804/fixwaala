import { collection, getCountFromServer, getAggregateFromServer, count, sum, query, where } from 'firebase/firestore'
import { db } from '@/lib/firebase'

export interface DashboardStats {
  totalCustomers: number
  totalProviders: number
  activeTickets: number
  failedTickets: number
  activeJobs: number
  completedJobs: number
  openReports: number
  unresolvedSafetyAlerts: number
  successfulPayments: number
  totalRevenue: number
  registeredDevices: number
}

const activeTicketStatuses = [
  'draft', 'matching', 'awaitingCustomerConfirmation', 'assigned', 'providerEnRoute',
  'providerArrived', 'underInspection', 'awaitingEstimateApproval', 'inProgress',
]

const activeJobStatuses = [
  'assigned', 'accepted', 'enRoute', 'arrived', 'checkedIn', 'inspecting',
  'estimateSubmitted', 'workInProgress', 'completionRequested',
]

/** Platform-wide counts via Firestore aggregation queries, mirroring AdminDashboardService.load(). */
export async function loadDashboardStats(): Promise<DashboardStats> {
  const usersCol = collection(db, 'users')
  const [
    customers, providers, activeTix, failedTix, activeJ, completedJ,
    openR, unresolvedAlerts, paymentAgg, devices,
  ] = await Promise.all([
    getCountFromServer(query(usersCol, where('role', '==', 'customer'))),
    getCountFromServer(query(usersCol, where('role', '==', 'provider'))),
    getCountFromServer(query(collection(db, 'tickets'), where('status', 'in', activeTicketStatuses))),
    getCountFromServer(query(collection(db, 'tickets'), where('status', '==', 'failed'))),
    getCountFromServer(query(collection(db, 'jobs'), where('status', 'in', activeJobStatuses))),
    getCountFromServer(query(collection(db, 'jobs'), where('status', '==', 'completed'))),
    getCountFromServer(query(collection(db, 'reports'), where('status', '==', 'open'))),
    getCountFromServer(query(collection(db, 'safetyAlerts'), where('resolved', '==', false))),
    getAggregateFromServer(query(collection(db, 'payments'), where('status', '==', 'success')), {
      paymentCount: count(),
      totalAmount: sum('amount'),
    }),
    getCountFromServer(collection(db, 'deviceTokens')),
  ])

  return {
    totalCustomers: customers.data().count,
    totalProviders: providers.data().count,
    activeTickets: activeTix.data().count,
    failedTickets: failedTix.data().count,
    activeJobs: activeJ.data().count,
    completedJobs: completedJ.data().count,
    openReports: openR.data().count,
    unresolvedSafetyAlerts: unresolvedAlerts.data().count,
    successfulPayments: paymentAgg.data().paymentCount,
    totalRevenue: paymentAgg.data().totalAmount ?? 0,
    registeredDevices: devices.data().count,
  }
}
