import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Flag } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ToneBadge, reportStatusTone, severityTone } from '@/components/shared/StatusBadge'
import { EmptyState } from '@/components/shared/EmptyState'
import { TableSkeletonRows } from '@/components/shared/TableSkeletonRows'
import { fetchReportPage, type ReportPage } from '@/services/adminModerationService'
import type { ReportStatus } from '@/types/enums'
import { reportDetailPath } from '@/routes'

export function ReportListScreen() {
  const navigate = useNavigate()
  const [status, setStatus] = useState<ReportStatus | 'all'>('open')
  const [page, setPage] = useState<ReportPage | null>(null)
  const [pageStack, setPageStack] = useState<ReportPage['lastDoc'][]>([])
  const [loading, setLoading] = useState(true)

  async function loadPage(startAfterDoc?: ReportPage['lastDoc']) {
    setLoading(true)
    try {
      setPage(await fetchReportPage({ status: status === 'all' ? undefined : status, startAfterDoc: startAfterDoc ?? undefined }))
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
    <PageScaffold title="Reports" subtitle="User-submitted reports against tickets, jobs, or other users" back={false}>
      <div className="mb-4">
        <Select value={status} onValueChange={(v) => setStatus(v as ReportStatus | 'all')}>
          <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            <SelectItem value="open">Open</SelectItem>
            <SelectItem value="underReview">Under review</SelectItem>
            <SelectItem value="resolved">Resolved</SelectItem>
            <SelectItem value="rejected">Rejected</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="overflow-x-auto rounded-xl border border-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Reason</TableHead>
              <TableHead>Severity</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Reported</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && <TableSkeletonRows columns={4} />}
            {!loading && (page?.reports ?? []).map((r) => (
              <TableRow
                key={r.id}
                className="cursor-pointer animate-in fade-in duration-200"
                onClick={() => navigate(reportDetailPath(r.id))}
              >
                <TableCell className="font-medium">{r.reason}</TableCell>
                <TableCell><ToneBadge value={r.severity} toneMap={severityTone} /></TableCell>
                <TableCell><ToneBadge value={r.status} toneMap={reportStatusTone} /></TableCell>
                <TableCell>{r.createdAt.toLocaleString()}</TableCell>
              </TableRow>
            ))}
            {!loading && page?.reports.length === 0 && (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={4}>
                  <EmptyState icon={Flag} title="No reports" description="Reports matching this filter will show up here." />
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
