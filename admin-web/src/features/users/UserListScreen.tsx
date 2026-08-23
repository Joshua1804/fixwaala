import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search, Users as UsersIcon } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ToneBadge, accountStatusTone } from '@/components/shared/StatusBadge'
import { EmptyState } from '@/components/shared/EmptyState'
import { TableSkeletonRows } from '@/components/shared/TableSkeletonRows'
import { fetchUserPage, searchUsers, type UserPage } from '@/services/adminUserService'
import type { AppUser } from '@/types/models'
import type { AccountStatus, UserRole } from '@/types/enums'
import { userDetailPath } from '@/routes'

export function UserListScreen() {
  const navigate = useNavigate()
  const [role, setRole] = useState<UserRole | 'all'>('all')
  const [status, setStatus] = useState<AccountStatus | 'all'>('all')
  const [searchTerm, setSearchTerm] = useState('')
  const [page, setPage] = useState<UserPage | null>(null)
  const [pageStack, setPageStack] = useState<UserPage['lastDoc'][]>([])
  const [loading, setLoading] = useState(true)
  const [searchResults, setSearchResults] = useState<AppUser[] | null>(null)

  async function loadPage(startAfterDoc?: UserPage['lastDoc']) {
    setLoading(true)
    try {
      const result = await fetchUserPage({
        role: role === 'all' ? undefined : role,
        status: role === 'all' || status === 'all' ? undefined : status,
        startAfterDoc: startAfterDoc ?? undefined,
      })
      setPage(result)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    setSearchResults(null)
    setPageStack([])
    loadPage()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [role, status])

  async function handleSearch(term: string) {
    setSearchTerm(term)
    if (!term.trim()) {
      setSearchResults(null)
      return
    }
    const results = await searchUsers(term)
    setSearchResults(results)
  }

  const rows = searchResults ?? page?.users ?? []

  return (
    <PageScaffold title="Users" subtitle="Browse and moderate customer and provider accounts" back={false}>
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative w-64">
          <Search className="absolute top-1/2 left-2.5 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search by email or name…"
            className="pl-8"
            value={searchTerm}
            onChange={(e) => handleSearch(e.target.value)}
          />
        </div>
        <Select value={role} onValueChange={(v) => setRole(v as UserRole | 'all')}>
          <SelectTrigger className="w-40"><SelectValue placeholder="Role" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All roles</SelectItem>
            <SelectItem value="customer">Customer</SelectItem>
            <SelectItem value="provider">Provider</SelectItem>
          </SelectContent>
        </Select>
        <Select value={status} onValueChange={(v) => setStatus(v as AccountStatus | 'all')} disabled={role === 'all'}>
          <SelectTrigger className="w-40"><SelectValue placeholder="Status" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All statuses</SelectItem>
            <SelectItem value="active">Active</SelectItem>
            <SelectItem value="restricted">Restricted</SelectItem>
            <SelectItem value="suspended">Suspended</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="overflow-x-auto rounded-xl border border-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Name</TableHead>
              <TableHead>Email</TableHead>
              <TableHead>Role</TableHead>
              <TableHead>Status</TableHead>
              <TableHead>Verified</TableHead>
              <TableHead>Created</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && <TableSkeletonRows columns={6} />}
            {!loading && rows.map((u) => (
              <TableRow
                key={u.id}
                className="cursor-pointer animate-in fade-in duration-200"
                onClick={() => navigate(userDetailPath(u.id))}
              >
                <TableCell className="font-medium">{u.name || '—'}</TableCell>
                <TableCell>{u.email}</TableCell>
                <TableCell className="capitalize">{u.role}</TableCell>
                <TableCell><ToneBadge value={u.accountStatus} toneMap={accountStatusTone} /></TableCell>
                <TableCell>{u.isVerified ? 'Yes' : 'No'}</TableCell>
                <TableCell>{u.createdAt.toLocaleDateString()}</TableCell>
              </TableRow>
            ))}
            {!loading && rows.length === 0 && (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={6}>
                  <EmptyState icon={UsersIcon} title="No users found" description="Try a different search term or filter." />
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      {!searchResults && (
        <div className="mt-4 flex items-center justify-between">
          <Button
            variant="outline"
            disabled={pageStack.length === 0 || loading}
            onClick={() => {
              const newStack = pageStack.slice(0, -1)
              setPageStack(newStack)
              loadPage(newStack[newStack.length - 1])
            }}
          >
            Previous
          </Button>
          <Button
            variant="outline"
            disabled={!page?.hasMore || loading}
            onClick={() => {
              if (!page?.lastDoc) return
              setPageStack([...pageStack, page.lastDoc])
              loadPage(page.lastDoc)
            }}
          >
            Next
          </Button>
        </div>
      )}
    </PageScaffold>
  )
}
