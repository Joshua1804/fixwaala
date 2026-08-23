import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { ToneBadge, ticketStatusTone, jobStatusTone } from '@/components/shared/StatusBadge'
import { Skeleton } from '@/components/ui/skeleton'
import { notify } from '@/lib/toast'
import { fetchTicket, fetchJobForTicket, forceCancelTicket } from '@/services/adminTicketJobService'
import { ticketIsActive } from '@/types/models'
import type { Ticket, Job } from '@/types/models'
import { jobDetailPath, routes } from '@/routes'

export function TicketDetailScreen() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [ticket, setTicket] = useState<Ticket | null>(null)
  const [job, setJob] = useState<Job | null>(null)
  const [loading, setLoading] = useState(true)
  const [reason, setReason] = useState('')
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (!id) return
    Promise.all([fetchTicket(id), fetchJobForTicket(id)]).then(([t, j]) => {
      setTicket(t)
      setJob(j)
      setLoading(false)
    })
  }, [id])

  if (loading) {
    return (
      <PageScaffold title="Ticket">
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <Skeleton className="h-48 rounded-2xl" />
          <Skeleton className="h-48 rounded-2xl" />
        </div>
      </PageScaffold>
    )
  }
  if (!ticket) return <PageScaffold title="Ticket not found"><p className="text-muted-foreground">This ticket may not exist.</p></PageScaffold>

  async function handleForceCancel() {
    if (!reason.trim()) {
      notify.error('A reason is required to force-cancel a ticket.')
      return
    }
    setSubmitting(true)
    try {
      await forceCancelTicket(ticket!, reason)
      setTicket(await fetchTicket(id!))
      notify.success('Ticket cancelled.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to cancel ticket.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <PageScaffold
      title={`Ticket · ${ticket.customerName || ticket.customerId}`}
      subtitle={`Created ${ticket.createdAt.toLocaleString()}`}
    >
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Details</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-3 text-sm">
            <div className="flex gap-2"><ToneBadge value={ticket.status} toneMap={ticketStatusTone} /></div>
            <p>{ticket.description}</p>
            <p className="text-muted-foreground capitalize">Category: {ticket.category}</p>
            {ticket.addressLine && <p className="text-muted-foreground">{ticket.addressLine}</p>}
            {ticket.aiSummary && <p className="text-muted-foreground italic">AI summary: {ticket.aiSummary}</p>}
            {ticket.imageUrls.length > 0 && (
              <div className="flex flex-wrap gap-2 pt-2">
                {ticket.imageUrls.map((url) => (
                  <a key={url} href={url} target="_blank" rel="noreferrer">
                    <img src={url} alt="Ticket" className="h-20 w-20 rounded-md object-cover" />
                  </a>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Linked job</CardTitle></CardHeader>
          <CardContent>
            {job ? (
              <button
                className="flex w-full items-center justify-between rounded-lg border border-border p-3 text-left hover:bg-muted"
                onClick={() => navigate(jobDetailPath(job!.jobId))}
              >
                <span className="text-sm">{job.providerName || job.providerId}</span>
                <ToneBadge value={job.status} toneMap={jobStatusTone} />
              </button>
            ) : (
              <p className="text-sm text-muted-foreground">No job assigned yet.</p>
            )}
          </CardContent>
        </Card>

        {ticketIsActive(ticket.status) && (
          <Card className="lg:col-span-2">
            <CardHeader><CardTitle>Force cancel</CardTitle></CardHeader>
            <CardContent className="flex flex-col gap-4">
              <Textarea placeholder="Reason (required)" value={reason} onChange={(e) => setReason(e.target.value)} rows={3} />
              <Button variant="destructive" disabled={submitting} onClick={handleForceCancel} className="self-start">
                {submitting ? 'Cancelling…' : 'Force cancel ticket'}
              </Button>
            </CardContent>
          </Card>
        )}
      </div>
      <Button variant="link" className="mt-4 px-0" onClick={() => navigate(routes.tickets)}>Back to tickets</Button>
    </PageScaffold>
  )
}
