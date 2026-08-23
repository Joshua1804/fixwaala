import { useMemo } from 'react'
import { History } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { EmptyState } from '@/components/shared/EmptyState'
import { TableSkeletonRows } from '@/components/shared/TableSkeletonRows'
import { RelativeTime } from '@/components/shared/RelativeTime'
import { useCollection } from '@/lib/useFirestore'
import { auditEventsQuery, mapAuditEvent } from '@/services/adminAuditService'

export function AuditLogScreen() {
  const query = useMemo(() => auditEventsQuery(), [])
  const { data, loading } = useCollection(query, mapAuditEvent)

  return (
    <PageScaffold title="Audit log" subtitle="Every privileged action taken through this admin app, newest first" back={false}>
      <div className="overflow-x-auto rounded-xl border border-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Action</TableHead>
              <TableHead>Target</TableHead>
              <TableHead>Admin</TableHead>
              <TableHead>When</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && <TableSkeletonRows columns={4} />}
            {!loading && data.map((e) => (
              <TableRow key={e.id} className="animate-in fade-in duration-200">
                <TableCell className="font-medium">{e.action}</TableCell>
                <TableCell className="text-muted-foreground">{e.targetType} · {e.targetId}</TableCell>
                <TableCell>{e.actorAdminEmail}</TableCell>
                <TableCell><RelativeTime date={e.createdAt} className="text-muted-foreground" /></TableCell>
              </TableRow>
            ))}
            {!loading && data.length === 0 && (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={4}>
                  <EmptyState icon={History} title="No audit events yet" description="Every privileged action taken through this app will be logged here." />
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </PageScaffold>
  )
}
