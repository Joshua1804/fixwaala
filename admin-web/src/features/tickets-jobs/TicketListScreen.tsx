import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Ticket as TicketIcon } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ToneBadge, ticketStatusTone } from '@/components/shared/StatusBadge'
import { EmptyState } from '@/components/shared/EmptyState'
import { TableSkeletonRows } from '@/components/shared/TableSkeletonRows'
import { fetchTicketPage, type TicketPage } from '@/services/adminTicketJobService'
import type { TicketStatus } from '@/types/enums'
import { ticketDetailPath } from '@/routes'

const statuses: TicketStatus[] = [
  'draft', 'matching', 'awaitingCustomerConfirmation', 'assigned', 'providerEnRoute',
  'providerArrived', 'underInspection', 'awaitingEstimateApproval', 'inProgress',
  'completed', 'paid', 'closed', 'cancelled', 'failed',
]

export function TicketListScreen() {
  const navigate = useNavigate()
  const [status, setStatus] = useState<TicketStatus | 'all'>('all')
  const [page, setPage] = useState<TicketPage | null>(null)
  const [pageStack, setPageStack] = useState<TicketPage['lastDoc'][]>([])
  const [loading, setLoading] = useState(true)

  async function loadPage(startAfterDoc?: TicketPage['lastDoc']) {
    setLoading(true)
    try {
      setPage(await fetchTicketPage({ status: status === 'all' ? undefined : status, startAfterDoc: startAfterDoc ?? undefined }))
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
    <PageScaffold title="Tickets" subtitle="Customer service requests" back={false}>
      <div className="mb-4">
        <Select value={status} onValueChange={(v) => setStatus(v as TicketStatus | 'all')}>
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
              <TableHead>Customer</TableHead>
              <TableHead>Category</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && <TableSkeletonRows columns={4} />}
            {!loading && (page?.tickets ?? []).map((t) => (
              <TableRow
                key={t.id}
                className="cursor-pointer animate-in fade-in duration-200"
                onClick={() => navigate(ticketDetailPath(t.id))}
              >
                <TableCell className="font-medium">{t.customerName || t.customerId}</TableCell>
                <TableCell className="capitalize">{t.category}</TableCell>
                <TableCell><ToneBadge value={t.status} toneMap={ticketStatusTone} /></TableCell>
                <TableCell>{t.createdAt.toLocaleString()}</TableCell>
              </TableRow>
            ))}
            {!loading && page?.tickets.length === 0 && (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={4}>
                  <EmptyState icon={TicketIcon} title="No tickets" description="Tickets matching this filter will show up here." />
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
