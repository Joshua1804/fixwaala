import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Skeleton } from '@/components/ui/skeleton'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { ToneBadge, accountStatusTone } from '@/components/shared/StatusBadge'
import { useConfirm } from '@/components/shared/ConfirmDialog'
import { notify } from '@/lib/toast'
import {
  fetchUser, updateUserProfile, setUserAccountStatus, setUserVerified, deleteUserProfile,
} from '@/services/adminUserService'
import type { AppUser } from '@/types/models'
import type { AccountStatus } from '@/types/enums'
import { useAdminAuth } from '@/auth/AdminAuthContext'
import { routes } from '@/routes'

export function UserDetailScreen() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { state } = useAdminAuth()
  const confirm = useConfirm()
  const [user, setUser] = useState<AppUser | null>(null)
  const [loading, setLoading] = useState(true)
  const [name, setName] = useState('')
  const [phone, setPhone] = useState('')
  const [saving, setSaving] = useState(false)
  const [statusReason, setStatusReason] = useState('')

  useEffect(() => {
    if (!id) return
    fetchUser(id).then((u) => {
      setUser(u)
      setName(u?.name ?? '')
      setPhone(u?.phone ?? '')
      setLoading(false)
    })
  }, [id])

  if (loading) {
    return (
      <PageScaffold title="User">
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <Skeleton className="h-48 rounded-2xl" />
          <Skeleton className="h-48 rounded-2xl" />
        </div>
      </PageScaffold>
    )
  }
  if (!user) return <PageScaffold title="User not found"><p className="text-muted-foreground">This account may have been deleted.</p></PageScaffold>

  async function refresh() {
    if (id) setUser(await fetchUser(id))
  }

  async function handleSaveProfile() {
    setSaving(true)
    try {
      await updateUserProfile(user!, { name, phone })
      await refresh()
      notify.success('Profile updated.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to update profile.')
    } finally {
      setSaving(false)
    }
  }

  async function handleStatusChange(newStatus: AccountStatus) {
    const reason = statusReason.trim() || `Set to ${newStatus} by admin`
    try {
      await setUserAccountStatus(user!, newStatus, reason)
      setStatusReason('')
      await refresh()
      notify.success(`Account set to ${newStatus}.`)
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to update account status.')
    }
  }

  async function handleToggleVerified(verified: boolean) {
    try {
      await setUserVerified(user!, verified)
      await refresh()
      notify.success(verified ? 'Provider verified.' : 'Verification revoked.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to update verification.')
    }
  }

  async function handleDelete() {
    const ok = await confirm({
      title: 'Delete this profile?',
      description: `This deletes ${user!.email}'s Firestore profile. It does not delete their Firebase Auth login — run scripts/admin/delete_user.js afterwards for that.`,
      confirmLabel: 'Delete profile',
      destructive: true,
    })
    if (!ok) return
    try {
      await deleteUserProfile(user!)
      notify.success('Profile deleted.')
      navigate(routes.users)
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to delete profile.')
    }
  }

  return (
    <PageScaffold
      title={user.name || user.email}
      subtitle={`${user.role} · ${user.email}`}
      actions={<Button variant="destructive" onClick={handleDelete}>Delete profile</Button>}
    >
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Profile</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <Label>Name</Label>
              <Input value={name} onChange={(e) => setName(e.target.value)} />
            </div>
            <div className="flex flex-col gap-2">
              <Label>Phone</Label>
              <Input value={phone} onChange={(e) => setPhone(e.target.value)} />
            </div>
            <Button onClick={handleSaveProfile} disabled={saving} className="self-start">
              {saving ? 'Saving…' : 'Save profile'}
            </Button>
          </CardContent>
        </Card>

        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Account standing</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-4">
            <div className="flex items-center gap-2">
              <span className="text-sm text-muted-foreground">Current status:</span>
              <ToneBadge value={user.accountStatus} toneMap={accountStatusTone} />
            </div>
            <div className="flex flex-col gap-2">
              <Label>Reason (optional)</Label>
              <Input
                placeholder="Reason for status change"
                value={statusReason}
                onChange={(e) => setStatusReason(e.target.value)}
              />
            </div>
            <Select onValueChange={(v) => handleStatusChange(v as AccountStatus)}>
              <SelectTrigger className="w-48"><SelectValue placeholder="Change status…" /></SelectTrigger>
              <SelectContent>
                <SelectItem value="active">Active</SelectItem>
                <SelectItem value="restricted">Restricted</SelectItem>
                <SelectItem value="suspended">Suspended</SelectItem>
              </SelectContent>
            </Select>

            {user.role === 'provider' && (
              <div className="flex items-center justify-between border-t border-border pt-4">
                <div>
                  <p className="text-sm font-medium text-foreground">Verified badge</p>
                  <p className="text-xs text-muted-foreground">Shown to customers when choosing a provider.</p>
                </div>
                <Switch checked={user.isVerified} onCheckedChange={handleToggleVerified} />
              </div>
            )}
          </CardContent>
        </Card>

        {user.providerProfile && (
          <Card className="transition-shadow hover:shadow-sm">
            <CardHeader><CardTitle>Provider details</CardTitle></CardHeader>
            <CardContent className="flex flex-col gap-2 text-sm">
              <p><span className="text-muted-foreground">Skills:</span> {user.providerProfile.skills.join(', ') || '—'}</p>
              <p><span className="text-muted-foreground">Experience:</span> {user.providerProfile.experienceYears ?? '—'} years</p>
              <p><span className="text-muted-foreground">Service area:</span> {user.providerProfile.serviceArea ?? '—'}</p>
              <p><span className="text-muted-foreground">Online:</span> {user.providerProfile.online ? 'Yes' : 'No'}</p>
            </CardContent>
          </Card>
        )}

        {user.customerProfile && (
          <Card className="transition-shadow hover:shadow-sm">
            <CardHeader><CardTitle>Customer address</CardTitle></CardHeader>
            <CardContent className="flex flex-col gap-2 text-sm">
              <p>{user.customerProfile.addressLine ?? '—'}</p>
              <p className="text-muted-foreground">{user.customerProfile.city ?? ''} {user.customerProfile.pincode ?? ''}</p>
            </CardContent>
          </Card>
        )}
      </div>
      <p className="mt-6 text-xs text-muted-foreground">
        Signed in as {state.status === 'signedIn' ? state.email : ''}
      </p>
    </PageScaffold>
  )
}
