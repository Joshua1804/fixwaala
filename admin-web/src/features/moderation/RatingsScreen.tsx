import { useEffect, useState } from 'react'
import { Star } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Button } from '@/components/ui/button'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { EmptyState } from '@/components/shared/EmptyState'
import { TableSkeletonRows } from '@/components/shared/TableSkeletonRows'
import { useConfirm } from '@/components/shared/ConfirmDialog'
import { notify } from '@/lib/toast'
import { fetchRatingPage, deleteRating, type RatingPage } from '@/services/adminModerationService'

export function RatingsScreen() {
  const confirm = useConfirm()
  const [maxStars, setMaxStars] = useState<string>('3')
  const [page, setPage] = useState<RatingPage | null>(null)
  const [pageStack, setPageStack] = useState<RatingPage['lastDoc'][]>([])
  const [loading, setLoading] = useState(true)

  async function loadPage(startAfterDoc?: RatingPage['lastDoc']) {
    setLoading(true)
    try {
      setPage(await fetchRatingPage({
        maxStars: maxStars === 'all' ? undefined : Number(maxStars),
        startAfterDoc: startAfterDoc ?? undefined,
      }))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    setPageStack([])
    loadPage()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [maxStars])

  async function handleDelete(id: string, jobId: string, stars: number) {
    const ok = await confirm({
      title: 'Delete this rating?',
      description: 'This permanently removes the rating and review. This cannot be undone.',
      confirmLabel: 'Delete rating',
      destructive: true,
    })
    if (!ok) return
    try {
      await deleteRating({ id, jobId, stars })
      notify.success('Rating deleted.')
      loadPage()
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to delete rating.')
    }
  }

  return (
    <PageScaffold title="Ratings" subtitle="Moderate low-star ratings and reviews" back={false}>
      <div className="mb-4">
        <Select value={maxStars} onValueChange={(v) => v !== null && setMaxStars(v)}>
          <SelectTrigger className="w-48"><SelectValue /></SelectTrigger>
          <SelectContent>
            <SelectItem value="2">2 stars and below</SelectItem>
            <SelectItem value="3">3 stars and below</SelectItem>
            <SelectItem value="all">All ratings</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="overflow-x-auto rounded-xl border border-border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Stars</TableHead>
              <TableHead>Review</TableHead>
              <TableHead>Direction</TableHead>
              <TableHead>Date</TableHead>
              <TableHead />
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading && <TableSkeletonRows columns={5} />}
            {!loading && (page?.ratings ?? []).map((r) => (
              <TableRow key={r.id} className="animate-in fade-in duration-200">
                <TableCell>
                  <div className="flex items-center gap-0.5">
                    {Array.from({ length: r.stars }).map((_, i) => (
                      <Star key={i} className="h-3.5 w-3.5 fill-warning text-warning" />
                    ))}
                  </div>
                </TableCell>
                <TableCell className="max-w-xs truncate">{r.review ?? '—'}</TableCell>
                <TableCell className="text-muted-foreground text-xs">{r.direction}</TableCell>
                <TableCell>{r.createdAt.toLocaleDateString()}</TableCell>
                <TableCell>
                  <Button size="sm" variant="destructive" onClick={() => handleDelete(r.id, r.jobId, r.stars)}>Delete</Button>
                </TableCell>
              </TableRow>
            ))}
            {!loading && page?.ratings.length === 0 && (
              <TableRow className="hover:bg-transparent">
                <TableCell colSpan={5}>
                  <EmptyState icon={Star} title="No ratings" description="Ratings at or below this threshold will show up here." />
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
