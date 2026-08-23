import { cn } from '@/lib/utils'

export type BadgeTone = 'neutral' | 'success' | 'warning' | 'error' | 'info' | 'primary'

const toneClasses: Record<BadgeTone, string> = {
  neutral: 'bg-muted text-muted-foreground',
  success: 'bg-success/12 text-success',
  warning: 'bg-warning/15 text-warning',
  error: 'bg-destructive/10 text-destructive',
  info: 'bg-info/12 text-info',
  primary: 'bg-primary/10 text-primary',
}

/** Small pill badge for status/priority/severity values, replacing Flutter's *_status_ui.dart chip widgets. */
export function StatusBadge({ label, tone = 'neutral' }: { label: string; tone?: BadgeTone }) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium capitalize',
        toneClasses[tone],
      )}
    >
      {label}
    </span>
  )
}

function splitCamelCase(s: string): string {
  return s.replace(/([a-z])([A-Z])/g, '$1 $2')
}

export const ticketStatusTone: Record<string, BadgeTone> = {
  draft: 'neutral',
  matching: 'info',
  awaitingCustomerConfirmation: 'warning',
  assigned: 'info',
  providerEnRoute: 'info',
  providerArrived: 'info',
  underInspection: 'info',
  awaitingEstimateApproval: 'warning',
  inProgress: 'primary',
  completed: 'success',
  paid: 'success',
  closed: 'neutral',
  cancelled: 'error',
  failed: 'error',
}

export const jobStatusTone: Record<string, BadgeTone> = {
  assigned: 'info',
  accepted: 'info',
  enRoute: 'info',
  arrived: 'info',
  checkedIn: 'info',
  inspecting: 'info',
  estimateSubmitted: 'warning',
  workInProgress: 'primary',
  completionRequested: 'warning',
  completed: 'success',
  cancelled: 'error',
}

export const paymentStatusTone: Record<string, BadgeTone> = {
  pending: 'warning',
  processing: 'info',
  success: 'success',
  failed: 'error',
}

export const reportStatusTone: Record<string, BadgeTone> = {
  open: 'warning',
  underReview: 'info',
  resolved: 'success',
  rejected: 'neutral',
}

export const severityTone: Record<string, BadgeTone> = {
  low: 'neutral',
  medium: 'warning',
  high: 'error',
}

export const accountStatusTone: Record<string, BadgeTone> = {
  active: 'success',
  restricted: 'warning',
  suspended: 'error',
}

export const announcementPriorityTone: Record<string, BadgeTone> = {
  info: 'info',
  warning: 'warning',
  critical: 'error',
}

/** Convenience wrapper: renders a StatusBadge from a value + tone map, humanizing camelCase. */
export function ToneBadge({ value, toneMap }: { value: string; toneMap: Record<string, BadgeTone> }) {
  return <StatusBadge label={splitCamelCase(value)} tone={toneMap[value] ?? 'neutral'} />
}
