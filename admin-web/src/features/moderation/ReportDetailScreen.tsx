import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { ToneBadge, reportStatusTone, severityTone } from '@/components/shared/StatusBadge'
import { Skeleton } from '@/components/ui/skeleton'
import { notify } from '@/lib/toast'
import { fetchReport, resolveReport } from '@/services/adminModerationService'
import type { Report } from '@/types/models'
import type { ReportStatus } from '@/types/enums'
import { useAdminAuth } from '@/auth/AdminAuthContext'
import { routes } from '@/routes'

export function ReportDetailScreen() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { state } = useAdminAuth()
  const [report, setReport] = useState<Report | null>(null)
  const [loading, setLoading] = useState(true)
  const [note, setNote] = useState('')
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (!id) return
    fetchReport(id).then((r) => {
      setReport(r)
      setNote(r?.adminNote ?? '')
      setLoading(false)
    })
  }, [id])

  if (loading) {
    return (
      <PageScaffold title="Report">
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <Skeleton className="h-48 rounded-2xl" />
          <Skeleton className="h-48 rounded-2xl" />
        </div>
      </PageScaffold>
    )
  }
  if (!report) return <PageScaffold title="Report not found"><p className="text-muted-foreground">This report may have been deleted.</p></PageScaffold>

  async function handleResolve(status: ReportStatus) {
    if (state.status !== 'signedIn') return
    setSubmitting(true)
    try {
      await resolveReport(report!, status, note, state.uid)
      notify.success(`Report marked ${status}.`)
      navigate(routes.reports)
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to resolve report.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <PageScaffold title={report.reason} subtitle={`Reported ${report.createdAt.toLocaleString()}`}>
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Details</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-3 text-sm">
            <div className="flex gap-2">
              <ToneBadge value={report.severity} toneMap={severityTone} />
              <ToneBadge value={report.status} toneMap={reportStatusTone} />
            </div>
            <p>{report.description}</p>
            <p className="text-muted-foreground">Reporter: {report.reporterId}</p>
            {report.againstUserId && <p className="text-muted-foreground">Against user: {report.againstUserId}</p>}
            {report.ticketId && <p className="text-muted-foreground">Ticket: {report.ticketId}</p>}
            {report.jobId && <p className="text-muted-foreground">Job: {report.jobId}</p>}
            {report.evidenceUrls.length > 0 && (
              <div className="flex flex-wrap gap-2 pt-2">
                {report.evidenceUrls.map((url) => (
                  <a key={url} href={url} target="_blank" rel="noreferrer">
                    <img src={url} alt="Evidence" className="h-20 w-20 rounded-md object-cover" />
                  </a>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Resolve</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-4">
            <Textarea placeholder="Admin note" value={note} onChange={(e) => setNote(e.target.value)} rows={4} />
            <div className="flex flex-wrap gap-2">
              <Button disabled={submitting} onClick={() => handleResolve('underReview')} variant="outline">Mark under review</Button>
              <Button disabled={submitting} onClick={() => handleResolve('resolved')}>Resolve</Button>
              <Button disabled={submitting} onClick={() => handleResolve('rejected')} variant="destructive">Reject</Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </PageScaffold>
  )
}
