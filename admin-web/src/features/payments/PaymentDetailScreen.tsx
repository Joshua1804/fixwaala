import { useEffect, useState } from 'react'
import { useParams } from 'react-router-dom'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { ToneBadge, paymentStatusTone } from '@/components/shared/StatusBadge'
import { Skeleton } from '@/components/ui/skeleton'
import { notify } from '@/lib/toast'
import { fetchPayment, setPaymentDispute } from '@/services/adminPaymentService'
import type { PaymentRecord, PaymentDisputeStatus } from '@/types/models'
import { useAdminAuth } from '@/auth/AdminAuthContext'

const currencyFormatter = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' })

export function PaymentDetailScreen() {
  const { id } = useParams<{ id: string }>()
  const { state } = useAdminAuth()
  const [payment, setPayment] = useState<PaymentRecord | null>(null)
  const [loading, setLoading] = useState(true)
  const [note, setNote] = useState('')
  const [submitting, setSubmitting] = useState(false)

  useEffect(() => {
    if (!id) return
    fetchPayment(id).then((p) => {
      setPayment(p)
      setNote(p?.disputeNote ?? '')
      setLoading(false)
    })
  }, [id])

  if (loading) {
    return (
      <PageScaffold title="Payment">
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <Skeleton className="h-40 rounded-2xl" />
          <Skeleton className="h-40 rounded-2xl" />
        </div>
      </PageScaffold>
    )
  }
  if (!payment) return <PageScaffold title="Payment not found"><p className="text-muted-foreground">This payment may not exist.</p></PageScaffold>

  async function handleDispute(status: PaymentDisputeStatus) {
    if (state.status !== 'signedIn') return
    setSubmitting(true)
    try {
      await setPaymentDispute(payment!, status, note, state.uid)
      setPayment(await fetchPayment(id!))
      notify.success(`Payment marked ${status}.`)
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to update dispute.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <PageScaffold title={currencyFormatter.format(payment.amount)} subtitle={`Job ${payment.jobId}`}>
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Details</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-2 text-sm">
            <div className="flex gap-2"><ToneBadge value={payment.status} toneMap={paymentStatusTone} /></div>
            <p><span className="text-muted-foreground">Method:</span> {payment.method.toUpperCase()}</p>
            <p><span className="text-muted-foreground">Customer:</span> {payment.customerId}</p>
            <p><span className="text-muted-foreground">Provider:</span> {payment.providerId}</p>
            <p><span className="text-muted-foreground">Processed:</span> {payment.processedAt.toLocaleString()}</p>
            {payment.failureReason && <p className="text-destructive">Failure: {payment.failureReason}</p>}
          </CardContent>
        </Card>

        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Dispute</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-4">
            <p className="text-sm text-muted-foreground">Current: {payment.disputeStatus}</p>
            <Textarea placeholder="Dispute note" value={note} onChange={(e) => setNote(e.target.value)} rows={4} />
            <div className="flex flex-wrap gap-2">
              <Button disabled={submitting} onClick={() => handleDispute('disputed')} variant="outline">Mark disputed</Button>
              <Button disabled={submitting} onClick={() => handleDispute('resolved')}>Resolve</Button>
              <Button disabled={submitting} onClick={() => handleDispute('refunded')} variant="destructive">Refund</Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </PageScaffold>
  )
}
