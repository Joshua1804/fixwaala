import { useEffect, useState } from 'react'
import { Users, UserCog, Ticket, XCircle, Briefcase, CheckCircle2, Flag, Siren, CreditCard, Smartphone, AlertTriangle } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { CountUp } from '@/components/shared/CountUp'
import { loadDashboardStats, type DashboardStats } from '@/services/adminDashboardService'

const currencyFormatter = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 })

interface StatDef {
  key: keyof DashboardStats
  label: string
  icon: typeof Users
  tone: 'primary' | 'success' | 'warning' | 'error' | 'info'
  format?: (n: number) => string
}

const toneClasses: Record<StatDef['tone'], string> = {
  primary: 'bg-primary/10 text-primary',
  success: 'bg-success/12 text-success',
  warning: 'bg-warning/15 text-warning',
  error: 'bg-destructive/10 text-destructive',
  info: 'bg-info/12 text-info',
}

const stats: StatDef[] = [
  { key: 'totalCustomers', label: 'Customers', icon: Users, tone: 'primary' },
  { key: 'totalProviders', label: 'Providers', icon: UserCog, tone: 'primary' },
  { key: 'activeTickets', label: 'Active tickets', icon: Ticket, tone: 'info' },
  { key: 'failedTickets', label: 'Failed tickets', icon: XCircle, tone: 'error' },
  { key: 'activeJobs', label: 'Active jobs', icon: Briefcase, tone: 'info' },
  { key: 'completedJobs', label: 'Completed jobs', icon: CheckCircle2, tone: 'success' },
  { key: 'openReports', label: 'Open reports', icon: Flag, tone: 'warning' },
  { key: 'unresolvedSafetyAlerts', label: 'Unresolved safety alerts', icon: Siren, tone: 'error' },
  { key: 'successfulPayments', label: 'Successful payments', icon: CreditCard, tone: 'success' },
  { key: 'totalRevenue', label: 'Total revenue', icon: CreditCard, tone: 'primary', format: (n) => currencyFormatter.format(n) },
  { key: 'registeredDevices', label: 'Registered devices', icon: Smartphone, tone: 'primary' },
]

export function DashboardScreen() {
  const [data, setData] = useState<DashboardStats | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    loadDashboardStats()
      .then((s) => !cancelled && setData(s))
      .catch((e) => !cancelled && setError(e instanceof Error ? e.message : String(e)))
      .finally(() => !cancelled && setLoading(false))
    return () => {
      cancelled = true
    }
  }, [])

  return (
    <PageScaffold title="Dashboard" subtitle="Platform-wide overview" back={false}>
      {error && (
        <div className="mb-6 flex items-center gap-2 rounded-xl border border-destructive/30 bg-destructive/8 px-4 py-3 text-sm text-destructive animate-in fade-in">
          <AlertTriangle className="h-4 w-4 shrink-0" />
          {error}
        </div>
      )}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        {stats.map((s, i) => (
          <Card
            key={s.key}
            className="animate-in fade-in slide-in-from-bottom-2 fill-mode-both transition-shadow duration-200 hover:shadow-md"
            style={{ animationDelay: `${i * 40}ms`, animationDuration: '400ms' }}
          >
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">{s.label}</CardTitle>
              <div className={`flex h-8 w-8 items-center justify-center rounded-full ${toneClasses[s.tone]}`}>
                <s.icon className="h-4 w-4" />
              </div>
            </CardHeader>
            <CardContent>
              {loading || !data ? (
                <Skeleton className="h-8 w-20" />
              ) : (
                <div className="text-2xl font-semibold text-foreground">
                  <CountUp value={data[s.key]} format={s.format} />
                </div>
              )}
            </CardContent>
          </Card>
        ))}
      </div>
    </PageScaffold>
  )
}
