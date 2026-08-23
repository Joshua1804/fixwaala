import { useMemo } from 'react'
import { ShieldCheck } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { EmptyState } from '@/components/shared/EmptyState'
import { TableSkeletonRows } from '@/components/shared/TableSkeletonRows'
import { useCollection } from '@/lib/useFirestore'
import { adminDirectoryQuery, mapAdminDirectoryEntry } from '@/services/adminDirectoryService'

export function AdminsScreen() {
  const query = useMemo(() => adminDirectoryQuery(), [])
  const { data, loading } = useCollection(query, mapAdminDirectoryEntry)
  const sorted = [...data].sort((a, b) => a.email.localeCompare(b.email))

  return (
    <PageScaffold
      title="Admins"
      subtitle="Accounts with admin access. Grant or revoke with scripts/admin/grant_admin_claim.js — this list is read-only."
      back={false}
    >
      <div className="overflow-x-auto rounded-xl border border-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Email</TableHead>
              <TableHead>Display name</TableHead>
              <TableHead>Granted</TableHead>
              <TableHead>Granted by</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && <TableSkeletonRows columns={4} />}
            {!loading && sorted.map((a) => (
              <TableRow key={a.uid} className="animate-in fade-in duration-200">
                <TableCell className="font-medium">{a.email}</TableCell>
                <TableCell>{a.displayName ?? '—'}</TableCell>
                <TableCell>{a.grantedAt ? a.grantedAt.toLocaleDateString() : '—'}</TableCell>
                <TableCell>{a.grantedBy ?? '—'}</TableCell>
              </TableRow>
            ))}
            {!loading && sorted.length === 0 && (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={4}>
                  <EmptyState icon={ShieldCheck} title="No admins found" />
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>
    </PageScaffold>
  )
}
