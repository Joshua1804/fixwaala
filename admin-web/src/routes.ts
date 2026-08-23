// Route paths, ported from lib/admin/core/admin_route_names.dart
export const routes = {
  login: '/login',
  dashboard: '/dashboard',
  users: '/users',
  userDetail: '/users/:id',
  admins: '/admins',
  tickets: '/tickets',
  ticketDetail: '/tickets/:id',
  jobs: '/jobs',
  jobDetail: '/jobs/:id',
  payments: '/payments',
  paymentDetail: '/payments/:id',
  reports: '/reports',
  reportDetail: '/reports/:id',
  safetyAlerts: '/safety-alerts',
  safetyAlertDetail: '/safety-alerts/:id',
  ratings: '/ratings',
  announcements: '/announcements',
  settings: '/settings',
  media: '/media',
  auditLog: '/audit-log',
  monitoring: '/monitoring',
} as const

export function userDetailPath(id: string) {
  return `/users/${id}`
}
export function ticketDetailPath(id: string) {
  return `/tickets/${id}`
}
export function jobDetailPath(id: string) {
  return `/jobs/${id}`
}
export function paymentDetailPath(id: string) {
  return `/payments/${id}`
}
export function reportDetailPath(id: string) {
  return `/reports/${id}`
}
export function safetyAlertDetailPath(id: string) {
  return `/safety-alerts/${id}`
}
