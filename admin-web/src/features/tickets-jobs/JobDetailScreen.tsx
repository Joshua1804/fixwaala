import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { ToneBadge, jobStatusTone } from '@/components/shared/StatusBadge'
import { Skeleton } from '@/components/ui/skeleton'
import { notify } from '@/lib/toast'
import { fetchJob, forceCancelJob } from '@/services/adminTicketJobService'
import { jobIsActive } from '@/types/models'
import type { Job } from '@/types/models'

const currencyFormatter = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' })

export function JobDetailScreen() {
  const { id } = useParams<{ id: string }>()
  const [job, setJob] = useState<Job | null>(null)
  const [loading, setLoading] = useState(true)
  const [reason, setReason] = useState('')
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (!id) return
    fetchJob(id).then((j) => {
      setJob(j)
      setLoading(false)
    })
  }, [id])

  if (loading) {
    return (
      <PageScaffold title="Job">
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <Skeleton className="h-48 rounded-2xl" />
          <Skeleton className="h-48 rounded-2xl" />
        </div>
      </PageScaffold>
    )
  }
  if (!job) return <PageScaffold title="Job not found"><p className="text-muted-foreground">This job may not exist.</p></PageScaffold>

  async function handleForceCancel() {
    if (!reason.trim()) {
      notify.error('A reason is required to force-cancel a job.')
      return
    }
    setSubmitting(true)
    try {
      await forceCancelJob(job!, reason)
      setJob(await fetchJob(id!))
      notify.success('Job cancelled.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to cancel job.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <PageScaffold title={`Job · ${job.providerName || job.providerId}`} subtitle={`Created ${job.createdAt.toLocaleString()}`}>
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Details</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-2 text-sm">
            <div className="flex gap-2"><ToneBadge value={job.status} toneMap={jobStatusTone} /></div>
            <p><span className="text-muted-foreground">Customer:</span> {job.customerName || job.customerId}</p>
            <p className="capitalize"><span className="text-muted-foreground">Category:</span> {job.category}</p>
            <p><span className="text-muted-foreground">Paid:</span> {job.paid ? 'Yes' : 'No'}</p>
            <p><span className="text-muted-foreground">Customer rated:</span> {job.customerRated ? 'Yes' : 'No'}</p>
            <p><span className="text-muted-foreground">Provider rated:</span> {job.providerRated ? 'Yes' : 'No'}</p>
            {job.hasOpenReport && <p className="text-destructive">Has an open report</p>}
            {job.hasSafetyAlert && <p className="text-destructive">Has a safety alert</p>}
          </CardContent>
        </Card>

        {job.estimate && (
          <Card className="transition-shadow hover:shadow-sm">
            <CardHeader><CardTitle>Estimate</CardTitle></CardHeader>
            <CardContent className="flex flex-col gap-2 text-sm">
              <p>{job.estimate.diagnosis}</p>
              <p><span className="text-muted-foreground">Labor:</span> {currencyFormatter.format(job.estimate.laborCharge)}</p>
              <p><span className="text-muted-foreground">Parts:</span> {currencyFormatter.format(job.estimate.partsCharge)}</p>
              <p className="font-medium">Total: {currencyFormatter.format(job.estimate.laborCharge + job.estimate.partsCharge)}</p>
              {job.estimate.notes && <p className="text-muted-foreground italic">{job.estimate.notes}</p>}
            </CardContent>
          </Card>
        )}

        {jobIsActive(job.status) && (
          <Card className="lg:col-span-2">
            <CardHeader><CardTitle>Force cancel</CardTitle></CardHeader>
            <CardContent className="flex flex-col gap-4">
              <Textarea placeholder="Reason (required)" value={reason} onChange={(e) => setReason(e.target.value)} rows={3} />
              <Button variant="destructive" disabled={submitting} onClick={handleForceCancel} className="self-start">
                {submitting ? 'Cancelling…' : 'Force cancel job'}
              </Button>
            </CardContent>
          </Card>
        )}
      </div>
    </PageScaffold>
  )
}
