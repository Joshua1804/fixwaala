import type { Timestamp, GeoPoint } from 'firebase/firestore'
import { enumOrDefault } from './enums'
import type {
  UserRole,
  ServiceCategory,
  TicketStatus,
  JobStatus,
  PaymentStatus,
  ReportSeverity,
  ReportStatus,
  RatingDirection,
  AccountStatus,
  AnnouncementPriority,
  AnnouncementAudience,
} from './enums'

function dateFrom(value: unknown): Date {
  if (value && typeof value === 'object' && 'toDate' in value) {
    return (value as Timestamp).toDate()
  }
  if (typeof value === 'string') {
    const parsed = new Date(value)
    if (!Number.isNaN(parsed.getTime())) return parsed
  }
  return new Date()
}

function dateFromOrNull(value: unknown): Date | null {
  if (value == null) return null
  return dateFrom(value)
}

function geoPointFrom(value: unknown): { latitude: number; longitude: number } | undefined {
  if (value && typeof value === 'object' && 'latitude' in value && 'longitude' in value) {
    const gp = value as GeoPoint
    return { latitude: gp.latitude, longitude: gp.longitude }
  }
  return undefined
}

// ── User (ported from lib/core/models/user_model.dart) ──────────────────

export interface CustomerProfile {
  addressLabel?: string
  addressLine?: string
  city?: string
  pincode?: string
}

export interface ProviderProfile {
  skills: ServiceCategory[]
  experienceYears?: number
  serviceArea?: string
  availability?: string
  online: boolean
  /** Fixed base/service-area pin the provider sets manually, distinct from their live GPS location. */
  baseAddress?: string
}

export interface AppUser {
  id: string
  email: string
  phone?: string
  role: UserRole
  name?: string
  photoUrl?: string
  emailVerified: boolean
  onboardingComplete: boolean
  accountStatus: AccountStatus
  isVerified: boolean
  customerProfile?: CustomerProfile
  providerProfile?: ProviderProfile
  createdAt: Date
  updatedAt?: Date
}

export function mapAppUser(_id: string, map: Record<string, unknown>): AppUser {
  return {
    id: (map.id as string) ?? _id,
    email: (map.email as string) ?? '',
    phone: map.phone as string | undefined,
    role: enumOrDefault<UserRole>(['customer', 'provider'], map.role as string, 'customer'),
    name: map.name as string | undefined,
    photoUrl: map.photoUrl as string | undefined,
    emailVerified: (map.emailVerified as boolean) ?? false,
    onboardingComplete: (map.onboardingComplete as boolean) ?? false,
    accountStatus: enumOrDefault<AccountStatus>(
      ['active', 'restricted', 'suspended'],
      map.accountStatus as string,
      'active',
    ),
    isVerified: (map.isVerified as boolean) ?? false,
    customerProfile: map.customerProfile as CustomerProfile | undefined,
    providerProfile: map.providerProfile as ProviderProfile | undefined,
    createdAt: dateFrom(map.createdAt),
    updatedAt: dateFromOrNull(map.updatedAt) ?? undefined,
  }
}

// ── Admin directory entry ────────────────────────────────────────────────

export interface AdminDirectoryEntry {
  uid: string
  email: string
  displayName?: string
  grantedAt?: Date
  grantedBy?: string
}

export function mapAdminDirectoryEntry(uid: string, map: Record<string, unknown>): AdminDirectoryEntry {
  return {
    uid,
    email: (map.email as string) ?? '',
    displayName: map.displayName as string | undefined,
    grantedAt: dateFromOrNull(map.grantedAt) ?? undefined,
    grantedBy: map.grantedBy as string | undefined,
  }
}

// ── Ticket (ported from lib/features/customer_ticket/models/ticket_model.dart) ──

export interface Ticket {
  id: string
  customerId: string
  customerName: string
  description: string
  imageUrls: string[]
  category: ServiceCategory
  status: TicketStatus
  assignedProviderId?: string
  addressLine?: string
  createdAt: Date
  updatedAt?: Date
  aiSummary?: string
  recommendedEquipment: string[]
  broadcastRadiusKm: number
  /** Coarse location, visible to providers browsing open tickets before a match is confirmed. */
  approximateLocation?: { latitude: number; longitude: number }
  /** Precise location, only populated once a provider is confirmed — the actual service address. */
  exactLocation?: { latitude: number; longitude: number }
}

const activeTicketStatuses: TicketStatus[] = [
  'draft',
  'matching',
  'awaitingCustomerConfirmation',
  'assigned',
  'providerEnRoute',
  'providerArrived',
  'underInspection',
  'awaitingEstimateApproval',
  'inProgress',
]

export function ticketIsActive(status: TicketStatus): boolean {
  return activeTicketStatuses.includes(status)
}

export function mapTicket(_id: string, map: Record<string, unknown>): Ticket {
  return {
    id: (map.id as string) ?? _id,
    customerId: (map.customerId as string) ?? '',
    customerName: (map.customerName as string) ?? (map.customerFirstName as string) ?? '',
    description: (map.description as string) ?? '',
    imageUrls: (map.imageUrls as string[]) ?? [],
    category: enumOrDefault<ServiceCategory>(
      ['plumber', 'electrician', 'carpenter', 'unknown'],
      map.category as string,
      'unknown',
    ),
    status: enumOrDefault<TicketStatus>(
      [
        'draft', 'matching', 'awaitingCustomerConfirmation', 'assigned', 'providerEnRoute',
        'providerArrived', 'underInspection', 'awaitingEstimateApproval', 'inProgress',
        'completed', 'paid', 'closed', 'cancelled', 'failed',
      ],
      map.status as string,
      'draft',
    ),
    assignedProviderId: map.assignedProviderId as string | undefined,
    addressLine: map.addressLine as string | undefined,
    createdAt: dateFrom(map.createdAt),
    updatedAt: dateFromOrNull(map.updatedAt) ?? undefined,
    aiSummary: map.aiSummary as string | undefined,
    recommendedEquipment: (map.recommendedEquipment as string[]) ?? [],
    broadcastRadiusKm: (map.broadcastRadiusKm as number) ?? 5,
    approximateLocation: geoPointFrom(map.approximateLocation),
    exactLocation: geoPointFrom(map.exactLocation),
  }
}

// ── Job (ported from lib/features/service_lifecycle/models/job_model.dart) ──

export interface RepairEstimate {
  diagnosis: string
  laborCharge: number
  partsCharge: number
  notes: string
  submittedAt: Date
}

export interface Job {
  jobId: string
  ticketId: string
  providerId: string
  providerName: string
  customerId: string
  customerName: string
  /** Denormalised onto the job since neither party can read the other's user document directly. */
  customerPhone?: string
  providerPhone?: string
  category: ServiceCategory
  status: JobStatus
  estimate?: RepairEstimate
  cancellationReason?: string
  hasOpenReport: boolean
  hasSafetyAlert: boolean
  paid: boolean
  paymentId?: string
  customerRated: boolean
  providerRated: boolean
  createdAt: Date
  acceptedAt?: Date
  enRouteAt?: Date
  arrivedAt?: Date
  completedAt?: Date
  closedAt?: Date
}

export function jobIsActive(status: JobStatus): boolean {
  return status !== 'completed' && status !== 'cancelled'
}

export function mapJob(_id: string, map: Record<string, unknown>): Job {
  const estimateMap = map.estimate as Record<string, unknown> | undefined
  return {
    jobId: (map.jobId as string) ?? _id,
    ticketId: (map.ticketId as string) ?? '',
    providerId: (map.providerId as string) ?? '',
    providerName: (map.providerName as string) ?? '',
    customerId: (map.customerId as string) ?? '',
    customerName: (map.customerName as string) ?? '',
    customerPhone: map.customerPhone as string | undefined,
    providerPhone: map.providerPhone as string | undefined,
    category: enumOrDefault<ServiceCategory>(
      ['plumber', 'electrician', 'carpenter', 'unknown'],
      map.category as string,
      'unknown',
    ),
    status: enumOrDefault<JobStatus>(
      ['assigned', 'accepted', 'enRoute', 'arrived', 'checkedIn', 'inspecting',
       'estimateSubmitted', 'workInProgress', 'completionRequested', 'completed', 'cancelled'],
      map.status as string,
      'assigned',
    ),
    estimate: estimateMap
      ? {
          diagnosis: (estimateMap.diagnosis as string) ?? '',
          laborCharge: (estimateMap.laborCharge as number) ?? 0,
          partsCharge: (estimateMap.partsCharge as number) ?? 0,
          notes: (estimateMap.notes as string) ?? '',
          submittedAt: dateFrom(estimateMap.submittedAt),
        }
      : undefined,
    cancellationReason: map.cancellationReason as string | undefined,
    hasOpenReport: (map.hasOpenReport as boolean) ?? false,
    hasSafetyAlert: (map.hasSafetyAlert as boolean) ?? false,
    paid: (map.paid as boolean) ?? false,
    paymentId: map.paymentId as string | undefined,
    customerRated: (map.customerRated as boolean) ?? false,
    providerRated: (map.providerRated as boolean) ?? false,
    createdAt: dateFrom(map.createdAt),
    acceptedAt: dateFromOrNull(map.acceptedAt) ?? undefined,
    enRouteAt: dateFromOrNull(map.enRouteAt) ?? undefined,
    arrivedAt: dateFromOrNull(map.arrivedAt) ?? undefined,
    completedAt: dateFromOrNull(map.completedAt) ?? undefined,
    closedAt: dateFromOrNull(map.closedAt) ?? undefined,
  }
}

// ── Payment (ported from lib/features/payment/models/payment_model.dart) ──

export type PaymentDisputeStatus = 'none' | 'disputed' | 'resolved' | 'refunded'

export interface PaymentRecord {
  id: string
  jobId: string
  customerId: string
  providerId: string
  amount: number
  method: string
  status: PaymentStatus
  failureReason?: string
  processedAt: Date
  disputeStatus: PaymentDisputeStatus
  disputeNote?: string
  disputeUpdatedAt?: Date
  disputeUpdatedByAdminId?: string
}

export function mapPayment(_id: string, map: Record<string, unknown>): PaymentRecord {
  return {
    id: (map.id as string) ?? _id,
    jobId: (map.jobId as string) ?? '',
    customerId: (map.customerId as string) ?? '',
    providerId: (map.providerId as string) ?? '',
    amount: (map.amount as number) ?? 0,
    method: (map.method as string) ?? '',
    status: enumOrDefault<PaymentStatus>(['pending', 'processing', 'success', 'failed'], map.status as string, 'pending'),
    failureReason: map.failureReason as string | undefined,
    processedAt: dateFrom(map.processedAt),
    disputeStatus: enumOrDefault<PaymentDisputeStatus>(
      ['none', 'disputed', 'resolved', 'refunded'],
      map.disputeStatus as string,
      'none',
    ),
    disputeNote: map.disputeNote as string | undefined,
    disputeUpdatedAt: dateFromOrNull(map.disputeUpdatedAt) ?? undefined,
    disputeUpdatedByAdminId: map.disputeUpdatedByAdminId as string | undefined,
  }
}

// ── Report / SafetyAlert (ported from lib/features/reports_safety/models/report_model.dart) ──

export interface Report {
  id: string
  reporterId: string
  againstUserId?: string
  ticketId?: string
  jobId?: string
  reason: string
  description: string
  evidenceUrls: string[]
  severity: ReportSeverity
  status: ReportStatus
  adminNote?: string
  resolvedByAdminId?: string
  createdAt: Date
  updatedAt?: Date
}

export function mapReport(_id: string, map: Record<string, unknown>): Report {
  return {
    id: (map.id as string) ?? _id,
    reporterId: (map.reporterId as string) ?? '',
    againstUserId: map.againstUserId as string | undefined,
    ticketId: map.ticketId as string | undefined,
    jobId: map.jobId as string | undefined,
    reason: (map.reason as string) ?? '',
    description: (map.description as string) ?? '',
    evidenceUrls: (map.evidenceUrls as string[]) ?? [],
    severity: enumOrDefault<ReportSeverity>(['low', 'medium', 'high'], map.severity as string, 'medium'),
    status: enumOrDefault<ReportStatus>(['open', 'underReview', 'resolved', 'rejected'], map.status as string, 'open'),
    adminNote: map.adminNote as string | undefined,
    resolvedByAdminId: map.resolvedByAdminId as string | undefined,
    createdAt: dateFrom(map.createdAt),
    updatedAt: dateFromOrNull(map.updatedAt) ?? undefined,
  }
}

export interface SafetyAlert {
  id: string
  userId: string
  ticketId?: string
  jobId?: string
  resolved: boolean
  resolvedByAdminId?: string
  raisedAt: Date
  resolvedAt?: Date
  /** Device GPS at the moment the alert was raised, best-effort — absent on older alerts or when location wasn't available. */
  raisedLocation?: { latitude: number; longitude: number }
}

export function mapSafetyAlert(_id: string, map: Record<string, unknown>): SafetyAlert {
  return {
    id: (map.id as string) ?? _id,
    userId: (map.userId as string) ?? '',
    ticketId: map.ticketId as string | undefined,
    jobId: map.jobId as string | undefined,
    resolved: (map.resolved as boolean) ?? false,
    resolvedByAdminId: map.resolvedByAdminId as string | undefined,
    raisedAt: dateFrom(map.raisedAt),
    resolvedAt: dateFromOrNull(map.resolvedAt) ?? undefined,
    raisedLocation: geoPointFrom(map.raisedLocation),
  }
}

// ── Rating (ported from lib/features/ratings/models/rating_model.dart) ──

export interface Rating {
  id: string
  jobId: string
  fromUserId: string
  toUserId: string
  direction: RatingDirection
  stars: number
  review?: string
  createdAt: Date
}

export function mapRating(_id: string, map: Record<string, unknown>): Rating {
  return {
    id: (map.id as string) ?? _id,
    jobId: (map.jobId as string) ?? '',
    fromUserId: (map.fromUserId as string) ?? '',
    toUserId: (map.toUserId as string) ?? '',
    direction: enumOrDefault<RatingDirection>(
      ['customerToProvider', 'providerToCustomer'],
      map.direction as string,
      'customerToProvider',
    ),
    stars: (map.stars as number) ?? 0,
    review: map.review as string | undefined,
    createdAt: dateFrom(map.createdAt),
  }
}

// ── Announcement (ported from lib/admin/features/content/models/announcement.dart) ──

export interface Announcement {
  id: string
  title: string
  body: string
  active: boolean
  priority: AnnouncementPriority
  audience: AnnouncementAudience
  createdAt: Date
  updatedAt?: Date
  expiresAt?: Date
  createdByAdminId: string
}

export function mapAnnouncement(_id: string, map: Record<string, unknown>): Announcement {
  return {
    id: (map.id as string) ?? _id,
    title: (map.title as string) ?? '',
    body: (map.body as string) ?? '',
    active: (map.active as boolean) ?? false,
    priority: enumOrDefault<AnnouncementPriority>(['info', 'warning', 'critical'], map.priority as string, 'info'),
    audience: enumOrDefault<AnnouncementAudience>(['all', 'customer', 'provider'], map.audience as string, 'all'),
    createdAt: dateFrom(map.createdAt),
    updatedAt: dateFromOrNull(map.updatedAt) ?? undefined,
    expiresAt: dateFromOrNull(map.expiresAt) ?? undefined,
    createdByAdminId: (map.createdByAdminId as string) ?? '',
  }
}

// ── Platform settings (singleton doc at platformSettings/config) ──

export interface PlatformSettings {
  maintenanceMode: boolean
  maintenanceMessage: string
  supportEmail: string
  supportPhone: string
  searchRadiiKm: number[]
  candidateReviewSeconds: number
  minSupportedAppVersion: string
  updatedAt?: Date
  updatedByAdminId?: string
}

export const defaultPlatformSettings: PlatformSettings = {
  maintenanceMode: false,
  maintenanceMessage: '',
  supportEmail: '',
  supportPhone: '',
  searchRadiiKm: [5, 10, 15],
  candidateReviewSeconds: 180,
  minSupportedAppVersion: '1.0.0',
}

export function mapPlatformSettings(_id: string, map: Record<string, unknown>): PlatformSettings {
  return {
    maintenanceMode: (map.maintenanceMode as boolean) ?? false,
    maintenanceMessage: (map.maintenanceMessage as string) ?? '',
    supportEmail: (map.supportEmail as string) ?? '',
    supportPhone: (map.supportPhone as string) ?? '',
    searchRadiiKm: (map.searchRadiiKm as number[]) ?? [5, 10, 15],
    candidateReviewSeconds: (map.candidateReviewSeconds as number) ?? 180,
    minSupportedAppVersion: (map.minSupportedAppVersion as string) ?? '1.0.0',
    updatedAt: dateFromOrNull(map.updatedAt) ?? undefined,
    updatedByAdminId: map.updatedByAdminId as string | undefined,
  }
}

// ── Audit event ──

export interface AuditEventModel {
  id: string
  actorAdminId: string
  actorAdminEmail: string
  action: string
  targetType: string
  targetId: string
  details: Record<string, unknown>
  createdAt: Date
}

// ── Monitoring ──

export interface CollectionHealth {
  name: string
  count: number
}
