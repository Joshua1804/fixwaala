import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { ShieldAlert, ChevronRight } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { StatusBadge } from '@/components/shared/StatusBadge'
import { EmptyState } from '@/components/shared/EmptyState'
import { TableSkeletonRows } from '@/components/shared/TableSkeletonRows'
import { notify } from '@/lib/toast'
import { useCollection } from '@/lib/useFirestore'
import { safetyAlertsQuery, mapSafetyAlert, resolveSafetyAlert } from '@/services/adminModerationService'
import { fetchUser } from '@/services/adminUserService'
import type { AppUser } from '@/types/models'
import { useAdminAuth } from '@/auth/AdminAuthContext'
import { safetyAlertDetailPath } from '@/routes'

export function SafetyAlertsScreen() {
  const { state } = useAdminAuth()
  const navigate = useNavigate()
  const [filter, setFilter] = useState<'all' | 'unresolved' | 'resolved'>('unresolved')
  const resolvedParam = filter === 'all' ? undefined : filter === 'resolved'
  const query = useMemo(() => safetyAlertsQuery(resolvedParam), [resolvedParam])
  const { data, loading } = useCollection(query, mapSafetyAlert)

  const [users, setUsers] = useState<Record<string, AppUser>>({})

  useEffect(() => {
    const missingIds = Array.from(new Set(data.map((a) => a.userId))).filter((id) => !users[id])
    if (missingIds.length === 0) return
    Promise.all(missingIds.map((id) => fetchUser(id))).then((fetched) => {
      setUsers((prev) => {
        const next = { ...prev }
        fetched.forEach((u, i) => {
          if (u) next[missingIds[i]!] = u
        })
        return next
      })
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data])

  async function handleResolve(id: string) {
    if (state.status !== 'signedIn') return
    try {
      await resolveSafetyAlert(id, state.uid)
      notify.success('Safety alert resolved.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to resolve alert.')
    }
  }

  return (
    <PageScaffold title="Safety alerts" subtitle="Live emergency (SOS) alerts raised during active jobs" back={false}>
      <div className="mb-4">
        <Select value={filter} onValueChange={(v) => setFilter(v as typeof filter)}>
          <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="unresolved">Unresolved</SelectItem>
            <SelectItem value="resolved">Resolved</SelectItem>
            <SelectItem value="all">All</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="overflow-x-auto rounded-xl border border-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Raised by</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Raised</TableHead>
              <TableHead />
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && <TableSkeletonRows columns={5} />}
            {!loading && data.map((a) => {
              const user = users[a.userId]
              return (
                <TableRow
                  key={a.id}
                  className={`cursor-pointer ${a.resolved ? '' : 'bg-destructive/3'}`}
                  onClick={() => navigate(safetyAlertDetailPath(a.id))}
                >
                  <TableCell className="font-medium">{user?.name || user?.email || 'Loading…'}</TableCell>
                  <TableCell>
                    {a.resolved ? <StatusBadge label="Resolved" tone="success" /> : <StatusBadge label="Unresolved" tone="error" />}
                  </TableCell>
                  <TableCell>{a.raisedAt.toLocaleString()}</TableCell>
                  <TableCell>
                    {!a.resolved && (
                      <Button size="sm" onClick={(e) => { e.stopPropagation(); handleResolve(a.id) }}>
                        Resolve
                      </Button>
                    )}
                  </TableCell>
                  <TableCell>
                    <ChevronRight className="h-4 w-4 text-muted-foreground" />
                  </TableCell>
                </TableRow>
              )
            })}
            {!loading && data.length === 0 && (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={5}>
                  <EmptyState icon={ShieldAlert} title="No safety alerts" description="Emergency alerts raised during active jobs will show up here in real time." />
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </PageScaffold>
  )
}
