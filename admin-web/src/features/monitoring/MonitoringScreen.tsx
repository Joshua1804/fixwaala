import { useEffect, useState } from 'react'
import { RefreshCw } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { TableSkeletonRows } from '@/components/shared/TableSkeletonRows'
import { notify } from '@/lib/toast'
import { loadCollectionHealth } from '@/services/adminMonitoringService'
import type { CollectionHealth } from '@/types/models'
import { cn } from '@/lib/utils'

export function MonitoringScreen() {
  const [data, setData] = useState<CollectionHealth[]>([])
  const [loading, setLoading] = useState(true)

  async function load(showToast?: boolean) {
    setLoading(true)
    try {
      setData(await loadCollectionHealth())
      if (showToast) notify.success('Counts refreshed.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to load collection counts.')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <PageScaffold
      title="Monitoring"
      subtitle="Raw document counts across key collections — is data flowing"
      back={false}
      actions={
        <Button variant="outline" onClick={() => load(true)} disabled={loading}>
          <RefreshCw className={cn('mr-1.5 h-4 w-4', loading && 'animate-spin')} /> Refresh
        </Button>
      }
    >
      <div className="overflow-x-auto rounded-xl border border-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Collection</TableHead>
              <TableHead className="text-right">Document count</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && <TableSkeletonRows columns={2} />}
            {!loading && data.map((c) => (
              <TableRow key={c.name} className="animate-in fade-in duration-200">
                <TableCell className="font-mono text-sm">{c.name}</TableCell>
                <TableCell className="text-right font-medium">{c.count.toLocaleString()}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </PageScaffold>
  )
}
