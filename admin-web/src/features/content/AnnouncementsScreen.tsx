import { useMemo, useState } from 'react'
import { Plus, Megaphone } from 'lucide-react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Switch } from '@/components/ui/switch'
import { Skeleton } from '@/components/ui/skeleton'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogTrigger } from '@/components/ui/dialog'
import { ToneBadge, announcementPriorityTone } from '@/components/shared/StatusBadge'
import { EmptyState } from '@/components/shared/EmptyState'
import { useConfirm } from '@/components/shared/ConfirmDialog'
import { notify } from '@/lib/toast'
import { useCollection } from '@/lib/useFirestore'
import {
  announcementsQuery, mapAnnouncement, createAnnouncement, updateAnnouncement,
  setAnnouncementActive, deleteAnnouncement,
} from '@/services/announcementService'
import type { Announcement } from '@/types/models'
import type { AnnouncementAudience, AnnouncementPriority } from '@/types/enums'
import { useAdminAuth } from '@/auth/AdminAuthContext'

function AnnouncementForm({
  initial, onSubmit, submitLabel,
}: {
  initial?: Announcement
  onSubmit: (fields: { title: string; body: string; priority: AnnouncementPriority; audience: AnnouncementAudience }) => Promise<void>
  submitLabel: string
}) {
  const [title, setTitle] = useState(initial?.title ?? '')
  const [body, setBody] = useState(initial?.body ?? '')
  const [priority, setPriority] = useState<AnnouncementPriority>(initial?.priority ?? 'info')
  const [audience, setAudience] = useState<AnnouncementAudience>(initial?.audience ?? 'all')
  const [submitting, setSubmitting] = useState(false)

  async function handleSubmit() {
    setSubmitting(true)
    try {
      await onSubmit({ title, body, priority, audience })
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-2">
        <Label>Title</Label>
        <Input value={title} onChange={(e) => setTitle(e.target.value)} />
      </div>
      <div className="flex flex-col gap-2">
        <Label>Body</Label>
        <Textarea value={body} onChange={(e) => setBody(e.target.value)} rows={4} />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <div className="flex flex-col gap-2">
          <Label>Priority</Label>
          <Select value={priority} onValueChange={(v) => setPriority(v as AnnouncementPriority)}>
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="info">Info</SelectItem>
              <SelectItem value="warning">Warning</SelectItem>
              <SelectItem value="critical">Critical</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="flex flex-col gap-2">
          <Label>Audience</Label>
          <Select value={audience} onValueChange={(v) => setAudience(v as AnnouncementAudience)}>
            <SelectTrigger><SelectValue /></SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All</SelectItem>
              <SelectItem value="customer">Customer</SelectItem>
              <SelectItem value="provider">Provider</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </div>
      <DialogFooter>
        <Button onClick={handleSubmit} disabled={submitting || !title.trim() || !body.trim()}>
          {submitting ? 'Saving…' : submitLabel}
        </Button>
      </DialogFooter>
    </div>
  )
}

export function AnnouncementsScreen() {
  const { state } = useAdminAuth()
  const confirm = useConfirm()
  const query = useMemo(() => announcementsQuery(), [])
  const { data, loading } = useCollection(query, mapAnnouncement)
  const [createOpen, setCreateOpen] = useState(false)
  const [editing, setEditing] = useState<Announcement | null>(null)

  async function handleCreate(fields: { title: string; body: string; priority: AnnouncementPriority; audience: AnnouncementAudience }) {
    if (state.status !== 'signedIn') return
    try {
      await createAnnouncement({ ...fields, adminId: state.uid })
      setCreateOpen(false)
      notify.success('Announcement created.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to create announcement.')
    }
  }

  async function handleUpdate(fields: { title: string; body: string; priority: AnnouncementPriority; audience: AnnouncementAudience }) {
    if (!editing) return
    try {
      await updateAnnouncement({ ...editing, ...fields })
      setEditing(null)
      notify.success('Announcement updated.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to update announcement.')
    }
  }

  async function handleToggleActive(a: Announcement, active: boolean) {
    try {
      await setAnnouncementActive(a, active)
      notify.success(active ? 'Announcement is live.' : 'Announcement hidden.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to update announcement.')
    }
  }

  async function handleDelete(a: Announcement) {
    const ok = await confirm({
      title: 'Delete this announcement?',
      description: `"${a.title}" will be permanently removed and stop showing in-app immediately.`,
      confirmLabel: 'Delete',
      destructive: true,
    })
    if (!ok) return
    try {
      await deleteAnnouncement(a)
      notify.success('Announcement deleted.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to delete announcement.')
    }
  }

  return (
    <PageScaffold
      title="Announcements"
      subtitle="Platform-wide banners shown in-app to customers and/or providers"
      back={false}
      actions={
        <Dialog open={createOpen} onOpenChange={setCreateOpen}>
          <DialogTrigger render={<Button />}>
            <Plus className="mr-1.5 h-4 w-4" />New announcement
          </DialogTrigger>
          <DialogContent>
            <DialogHeader><DialogTitle>New announcement</DialogTitle></DialogHeader>
            <AnnouncementForm onSubmit={handleCreate} submitLabel="Create" />
          </DialogContent>
        </Dialog>
      }
    >
      {loading && (
        <div className="flex flex-col gap-3">
          {Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-24 rounded-xl" />)}
        </div>
      )}
      {!loading && (
        <div className="flex flex-col gap-3">
          {data.map((a, i) => (
            <div
              key={a.id}
              className="flex items-start justify-between gap-4 rounded-xl border border-border bg-card p-4 animate-in fade-in slide-in-from-bottom-1 fill-mode-both transition-shadow hover:shadow-sm"
              style={{ animationDelay: `${i * 30}ms`, animationDuration: '300ms' }}
            >
              <div className="flex-1">
                <div className="mb-1 flex items-center gap-2">
                  <h3 className="font-medium text-foreground">{a.title}</h3>
                  <ToneBadge value={a.priority} toneMap={announcementPriorityTone} />
                  <span className="text-xs text-muted-foreground capitalize">{a.audience}</span>
                </div>
                <p className="text-sm text-muted-foreground">{a.body}</p>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                <Switch checked={a.active} onCheckedChange={(v) => handleToggleActive(a, v)} />
                <Dialog open={editing?.id === a.id} onOpenChange={(open) => setEditing(open ? a : null)}>
                  <DialogTrigger render={<Button size="sm" variant="outline" />}>Edit</DialogTrigger>
                  <DialogContent>
                    <DialogHeader><DialogTitle>Edit announcement</DialogTitle></DialogHeader>
                    <AnnouncementForm initial={a} onSubmit={handleUpdate} submitLabel="Save" />
                  </DialogContent>
                </Dialog>
                <Button size="sm" variant="destructive" onClick={() => handleDelete(a)}>Delete</Button>
              </div>
            </div>
          ))}
          {data.length === 0 && (
            <EmptyState icon={Megaphone} title="No announcements yet" description="Create one to show a banner to customers and/or providers in-app." />
          )}
        </div>
      )}
    </PageScaffold>
  )
}
