import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Phone, MapPin, User, UserCog, Briefcase, Siren } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'
import { StatusBadge, ToneBadge, jobStatusTone } from '@/components/shared/StatusBadge'
import { LocationMap } from '@/components/shared/LocationMap'
import { notify } from '@/lib/toast'
import { fetchSafetyAlert, resolveSafetyAlert } from '@/services/adminModerationService'
import { fetchJob, fetchTicket } from '@/services/adminTicketJobService'
import { fetchUser } from '@/services/adminUserService'
import type { SafetyAlert, Job, Ticket, AppUser } from '@/types/models'
import { useAdminAuth } from '@/auth/AdminAuthContext'
import { jobDetailPath } from '@/routes'

interface PersonInfo {
  user: AppUser | null
  phone?: string
  role: 'customer' | 'provider'
}

function PersonCard({ title, info, highlight }: { title: string; info: PersonInfo | null; highlight?: boolean }) {
  if (!info) {
    return (
      <Card>
        <CardHeader><CardTitle>{title}</CardTitle></CardHeader>
        <CardContent><p className="text-sm text-muted-foreground">No linked job — nothing to show.</p></CardContent>
      </Card>
    )
  }
  const { user, phone, role } = info
  const address = role === 'customer' ? user?.customerProfile : undefined
  const baseAddress = role === 'provider' ? user?.providerProfile : undefined

  return (
    <Card className={highlight ? 'ring-2 ring-destructive/40' : undefined}>
      <CardHeader><CardTitle>{title}</CardTitle></CardHeader>
      <CardContent className="flex flex-col gap-2 text-sm">
        <p className="font-medium text-foreground">{user?.name || user?.email || 'Unknown user'}</p>
        {user?.email && <p className="text-muted-foreground">{user.email}</p>}
        {phone && (
          <a href={`tel:${phone}`} className="flex items-center gap-1.5 text-primary hover:underline">
            <Phone className="h-3.5 w-3.5" /> {phone}
          </a>
        )}
        {address && (address.addressLine || address.city) && (
          <div className="flex items-start gap-1.5 pt-1 text-muted-foreground">
            <MapPin className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            <span>
              {address.addressLine}
              {address.city ? `, ${address.city}` : ''}
              {address.pincode ? ` ${address.pincode}` : ''}
            </span>
          </div>
        )}
        {baseAddress?.baseAddress && (
          <div className="flex items-start gap-1.5 pt-1 text-muted-foreground">
            <MapPin className="mt-0.5 h-3.5 w-3.5 shrink-0" />
            <span>{baseAddress.baseAddress}</span>
          </div>
        )}
        {!address?.addressLine && !baseAddress?.baseAddress && (
          <p className="pt-1 text-xs text-muted-foreground italic">No address on file.</p>
        )}
      </CardContent>
    </Card>
  )
}

export function SafetyAlertDetailScreen() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { state } = useAdminAuth()

  const [alert, setAlert] = useState<SafetyAlert | null>(null)
  const [job, setJob] = useState<Job | null>(null)
  const [ticket, setTicket] = useState<Ticket | null>(null)
  const [raiser, setRaiser] = useState<AppUser | null>(null)
  const [customer, setCustomer] = useState<AppUser | null>(null)
  const [provider, setProvider] = useState<AppUser | null>(null)
  const [loading, setLoading] = useState(true)
  const [resolving, setResolving] = useState(false)

  useEffect(() => {
    if (!id) return
    let cancelled = false

    async function load() {
      setLoading(true)
      const a = await fetchSafetyAlert(id!)
      if (cancelled) return
      setAlert(a)
      if (!a) {
        setLoading(false)
        return
      }

      const [raiserUser, loadedJob] = await Promise.all([
        fetchUser(a.userId),
        a.jobId ? fetchJob(a.jobId) : Promise.resolve(null),
      ])
      if (cancelled) return
      setRaiser(raiserUser)
      setJob(loadedJob)

      const ticketId = loadedJob?.ticketId ?? a.ticketId
      const [loadedTicket, customerUser, providerUser] = await Promise.all([
        ticketId ? fetchTicket(ticketId) : Promise.resolve(null),
        loadedJob ? fetchUser(loadedJob.customerId) : Promise.resolve(null),
        loadedJob ? fetchUser(loadedJob.providerId) : Promise.resolve(null),
      ])
      if (cancelled) return
      setTicket(loadedTicket)
      setCustomer(customerUser)
      setProvider(providerUser)
      setLoading(false)
    }

    load()
    return () => {
      cancelled = true
    }
  }, [id])

  if (loading) {
    return (
      <PageScaffold title="Safety alert">
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-48 rounded-2xl" />)}
        </div>
      </PageScaffold>
    )
  }

  if (!alert) {
    return <PageScaffold title="Safety alert not found"><p className="text-muted-foreground">This alert may have been removed.</p></PageScaffold>
  }

  async function handleResolve() {
    if (state.status !== 'signedIn') return
    setResolving(true)
    try {
      await resolveSafetyAlert(alert!.id, state.uid)
      setAlert({ ...alert!, resolved: true, resolvedByAdminId: state.uid, resolvedAt: new Date() })
      notify.success('Safety alert resolved.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to resolve alert.')
    } finally {
      setResolving(false)
    }
  }

  const location = alert.raisedLocation ?? ticket?.exactLocation ?? ticket?.approximateLocation
  const locationSource = alert.raisedLocation
    ? 'device'
    : ticket?.exactLocation
      ? 'exact-job'
      : ticket?.approximateLocation
        ? 'approximate-job'
        : null
  const raiserIsProvider = job ? alert.userId === job.providerId : false

  return (
    <PageScaffold
      title={`Safety alert · ${raiser?.name || raiser?.email || alert.userId}`}
      subtitle={`Raised ${alert.raisedAt.toLocaleString()}`}
      actions={
        !alert.resolved && (
          <Button variant="destructive" onClick={handleResolve} disabled={resolving}>
            <Siren className="mr-1.5 h-4 w-4" />
            {resolving ? 'Resolving…' : 'Mark resolved'}
          </Button>
        )
      }
    >
      <div className="mb-6 flex flex-wrap items-center gap-3 rounded-xl border border-border bg-card p-4">
        {alert.resolved ? (
          <StatusBadge label="Resolved" tone="success" />
        ) : (
          <StatusBadge label="Unresolved — needs action" tone="error" />
        )}
        <span className="text-sm text-muted-foreground">Raised by {raiser?.name || raiser?.email || alert.userId}</span>
        {raiser && (
          <span className="text-sm text-muted-foreground">
            ({raiserIsProvider ? 'provider' : job ? 'customer' : 'unknown role'})
          </span>
        )}
        {alert.resolved && alert.resolvedAt && (
          <span className="text-sm text-muted-foreground">
            · Resolved {alert.resolvedAt.toLocaleString()} by {alert.resolvedByAdminId}
          </span>
        )}
      </div>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <PersonCard
          title="Customer"
          highlight={!raiserIsProvider}
          info={job ? { user: customer, phone: job.customerPhone ?? customer?.phone, role: 'customer' } : null}
        />
        <PersonCard
          title="Provider"
          highlight={raiserIsProvider}
          info={job ? { user: provider, phone: job.providerPhone ?? provider?.phone, role: 'provider' } : null}
        />

        <Card>
          <CardHeader><CardTitle>Job</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-2 text-sm">
            {job ? (
              <>
                <div className="flex items-center gap-2">
                  <ToneBadge value={job.status} toneMap={jobStatusTone} />
                  <span className="capitalize text-muted-foreground">{job.category}</span>
                </div>
                {ticket?.description && <p>{ticket.description}</p>}
                <Button size="sm" variant="outline" className="mt-1 self-start" onClick={() => navigate(jobDetailPath(job.jobId))}>
                  <Briefcase className="mr-1.5 h-3.5 w-3.5" /> Open full job
                </Button>
              </>
            ) : (
              <p className="text-muted-foreground">No linked job on this alert.</p>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader><CardTitle>Location</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-3">
            {location ? (
              <>
                <LocationMap
                  latitude={location.latitude}
                  longitude={location.longitude}
                  label={locationSource === 'device' ? 'Alert location' : 'Job location'}
                />
                {locationSource === 'device' && (
                  <p className="text-xs text-success">Device GPS captured at the moment the alert was raised.</p>
                )}
                {locationSource === 'exact-job' && (
                  <p className="text-xs text-muted-foreground">
                    No GPS was captured on this alert (older alert, or location was unavailable) — showing the
                    linked job's exact service address instead.
                  </p>
                )}
                {locationSource === 'approximate-job' && (
                  <p className="text-xs text-muted-foreground">
                    No GPS was captured on this alert and the job has no exact address yet — showing the
                    approximate service area instead.
                  </p>
                )}
                {ticket?.addressLine && <p className="text-sm text-foreground">{ticket.addressLine}</p>}
              </>
            ) : (
              <p className="text-sm text-muted-foreground">No location available for this alert.</p>
            )}
          </CardContent>
        </Card>
      </div>

      <div className="mt-6 flex items-center gap-4 text-xs text-muted-foreground">
        <span className="flex items-center gap-1"><User className="h-3.5 w-3.5" /> Alert ID: {alert.id}</span>
        {job && <span className="flex items-center gap-1"><UserCog className="h-3.5 w-3.5" /> Job ID: {job.jobId}</span>}
      </div>
    </PageScaffold>
  )
}
