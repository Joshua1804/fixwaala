import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { CreditCard } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ToneBadge, paymentStatusTone } from '@/components/shared/StatusBadge'
import { EmptyState } from '@/components/shared/EmptyState'
import { TableSkeletonRows } from '@/components/shared/TableSkeletonRows'
import { fetchPaymentPage, type PaymentPage } from '@/services/adminPaymentService'
import type { PaymentStatus } from '@/types/enums'
import { paymentDetailPath } from '@/routes'

const currencyFormatter = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' })

export function PaymentListScreen() {
  const navigate = useNavigate()
  const [status, setStatus] = useState<PaymentStatus | 'all'>('all')
  const [page, setPage] = useState<PaymentPage | null>(null)
  const [pageStack, setPageStack] = useState<PaymentPage['lastDoc'][]>([])
  const [loading, setLoading] = useState(true)

  async function loadPage(startAfterDoc?: PaymentPage['lastDoc']) {
    setLoading(true)
    try {
      setPage(await fetchPaymentPage({ status: status === 'all' ? undefined : status, startAfterDoc: startAfterDoc ?? undefined }))
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
    <PageScaffold title="Payments" subtitle="Cross-user oversight of simulated payments" back={false}>
      <div className="mb-4">
        <Select value={status} onValueChange={(v) => setStatus(v as PaymentStatus | 'all')}>
          <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            <SelectItem value="pending">Pending</SelectItem>
            <SelectItem value="processing">Processing</SelectItem>
            <SelectItem value="success">Success</SelectItem>
            <SelectItem value="failed">Failed</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="overflow-x-auto rounded-xl border border-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Amount</TableHead>
              <TableHead>Method</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Dispute</TableHead>
              <TableHead>Processed</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && <TableSkeletonRows columns={5} />}
            {!loading && (page?.payments ?? []).map((p) => (
              <TableRow
                key={p.id}
                className="cursor-pointer animate-in fade-in duration-200"
                onClick={() => navigate(paymentDetailPath(p.id))}
              >
                <TableCell className="font-medium">{currencyFormatter.format(p.amount)}</TableCell>
                <TableCell className="uppercase text-xs">{p.method}</TableCell>
                <TableCell><ToneBadge value={p.status} toneMap={paymentStatusTone} /></TableCell>
                <TableCell className="text-muted-foreground">{p.disputeStatus === 'none' ? '—' : p.disputeStatus}</TableCell>
                <TableCell>{p.processedAt.toLocaleString()}</TableCell>
              </TableRow>
            ))}
            {!loading && page?.payments.length === 0 && (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={5}>
                  <EmptyState icon={CreditCard} title="No payments" description="Payments matching this filter will show up here." />
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
