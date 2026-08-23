import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Image } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Button } from '@/components/ui/button'
import { Skeleton } from '@/components/ui/skeleton'
import { EmptyState } from '@/components/shared/EmptyState'
import { fetchTicketPage, type TicketPage } from '@/services/adminTicketJobService'
import { ticketDetailPath } from '@/routes'

/** Photos on customer tickets — the only media Fixwaala stores. No Firebase Storage bucket; photos live on Cloudinary, referenced by URL from tickets/{id}.imageUrls. */
export function MediaScreen() {
  const navigate = useNavigate()
  const [page, setPage] = useState<TicketPage | null>(null)
  const [pageStack, setPageStack] = useState<TicketPage['lastDoc'][]>([])
  const [loading, setLoading] = useState(true)

  async function loadPage(startAfterDoc?: TicketPage['lastDoc']) {
    setLoading(true)
    try {
      setPage(await fetchTicketPage({ startAfterDoc: startAfterDoc ?? undefined, pageLimit: 40 }))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadPage()
  }, [])

  const withPhotos = (page?.tickets ?? []).filter((t) => t.imageUrls.length > 0)

  return (
    <PageScaffold title="Media" subtitle="Photos attached to customer tickets, newest tickets first" back={false}>
      {loading && (
        <div className="flex flex-col gap-4">
          {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-40 rounded-2xl" />)}
        </div>
      )}
      {!loading && withPhotos.length === 0 && (
        <EmptyState icon={Image} title="No photos on this page" description="Photos attached to customer tickets will show up here." />
      )}
      {!loading && (
        <div className="flex flex-col gap-4">
          {withPhotos.map((ticket, i) => (
            <div
              key={ticket.id}
              className="rounded-2xl border border-border bg-card p-4 animate-in fade-in slide-in-from-bottom-1 fill-mode-both transition-shadow hover:shadow-sm"
              style={{ animationDelay: `${i * 40}ms`, animationDuration: '300ms' }}
            >
              <div className="mb-3 flex items-center justify-between">
                <h3 className="text-sm font-medium text-foreground">{ticket.customerName || 'Customer'}</h3>
                <div className="flex items-center gap-3">
                  <span className="text-xs text-muted-foreground">{ticket.createdAt.toLocaleDateString()}</span>
                  <Button size="sm" variant="ghost" onClick={() => navigate(ticketDetailPath(ticket.id))}>Open ticket</Button>
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                {ticket.imageUrls.map((url) => (
                  <a key={url} href={url} target="_blank" rel="noreferrer" className="transition-transform hover:scale-105">
                    <img src={url} alt="Ticket attachment" className="h-24 w-24 rounded-[10px] object-cover" />
                  </a>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}

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
