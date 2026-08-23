import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Briefcase } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ToneBadge, jobStatusTone } from '@/components/shared/StatusBadge'
import { EmptyState } from '@/components/shared/EmptyState'
import { TableSkeletonRows } from '@/components/shared/TableSkeletonRows'
import { fetchJobPage, type JobPage } from '@/services/adminTicketJobService'
import type { JobStatus } from '@/types/enums'
import { jobDetailPath } from '@/routes'

const statuses: JobStatus[] = [
  'assigned', 'accepted', 'enRoute', 'arrived', 'checkedIn', 'inspecting',
  'estimateSubmitted', 'workInProgress', 'completionRequested', 'completed', 'cancelled',
]

export function JobListScreen() {
  const navigate = useNavigate()
  const [status, setStatus] = useState<JobStatus | 'all'>('all')
  const [page, setPage] = useState<JobPage | null>(null)
  const [pageStack, setPageStack] = useState<JobPage['lastDoc'][]>([])
  const [loading, setLoading] = useState(true)

  async function loadPage(startAfterDoc?: JobPage['lastDoc']) {
    setLoading(true)
    try {
      setPage(await fetchJobPage({ status: status === 'all' ? undefined : status, startAfterDoc: startAfterDoc ?? undefined }))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    setPageStack([])
    loadPage()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status])

  return (
    <PageScaffold title="Jobs" subtitle="Confirmed provider engagements" back={false}>
      <div className="mb-4">
        <Select value={status} onValueChange={(v) => setStatus(v as JobStatus | 'all')}>
          <SelectTrigger className="w-56"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            {statuses.map((s) => <SelectItem key={s} value={s}>{s}</SelectItem>)}
          </SelectContent>
        </Select>
      </div>

      <div className="overflow-x-auto rounded-xl border border-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Provider</TableHead>
              <TableHead>Customer</TableHead>
              <TableHead>Category</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && <TableSkeletonRows columns={5} />}
            {!loading && (page?.jobs ?? []).map((j) => (
              <TableRow
                key={j.jobId}
                className="cursor-pointer animate-in fade-in duration-200"
                onClick={() => navigate(jobDetailPath(j.jobId))}
              >
                <TableCell className="font-medium">{j.providerName || j.providerId}</TableCell>
                <TableCell>{j.customerName || j.customerId}</TableCell>
                <TableCell className="capitalize">{j.category}</TableCell>
                <TableCell><ToneBadge value={j.status} toneMap={jobStatusTone} /></TableCell>
                <TableCell>{j.createdAt.toLocaleString()}</TableCell>
              </TableRow>
            ))}
            {!loading && page?.jobs.length === 0 && (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={5}>
                  <EmptyState icon={Briefcase} title="No jobs" description="Jobs matching this filter will show up here." />
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      <div className="mt-4 flex items-center justify-between">
        <Button variant="outline" disabled={pageStack.length === 0 || loading} onClick={() => {
          const newStack = pageStack.slice(0, -1)
          setPageStack(newStack)
          loadPage(newStack[newStack.length - 1])
        }}>Previous</Button>
        <Button variant="outline" disabled={!page?.hasMore || loading} onClick={() => {
          if (!page?.lastDoc) return
          setPageStack([...pageStack, page.lastDoc])
          loadPage(page.lastDoc)
        }}>Next</Button>
      </div>
    </PageScaffold>
  )
}
