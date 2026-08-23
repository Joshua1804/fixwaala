import { useEffect, useState } from 'react'
import { PageScaffold } from '@/components/shared/PageScaffold'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Switch } from '@/components/ui/switch'
import { Skeleton } from '@/components/ui/skeleton'
import { notify } from '@/lib/toast'
import { fetchPlatformSettings, savePlatformSettings } from '@/services/platformSettingsService'
import { defaultPlatformSettings, type PlatformSettings } from '@/types/models'
import { useAdminAuth } from '@/auth/AdminAuthContext'

export function PlatformSettingsScreen() {
  const { state } = useAdminAuth()
  const [settings, setSettings] = useState<PlatformSettings>(defaultPlatformSettings)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    fetchPlatformSettings().then((s) => {
      setSettings(s)
      setLoading(false)
    })
  }, [])

  async function handleSave() {
    if (state.status !== 'signedIn') return
    setSaving(true)
    try {
      await savePlatformSettings(settings, state.uid)
      notify.success('Settings saved.')
    } catch (e) {
      notify.error(e instanceof Error ? e.message : 'Failed to save settings.')
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <PageScaffold title="Settings" back={false}>
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          {Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-40 rounded-2xl" />)}
        </div>
      </PageScaffold>
    )
  }

  return (
    <PageScaffold
      title="Platform settings"
      subtitle="Global tunables at platformSettings/config"
      back={false}
      actions={<Button onClick={handleSave} disabled={saving}>{saving ? 'Saving…' : 'Save settings'}</Button>}
    >
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Maintenance</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-4">
            <div className="flex items-center justify-between">
              <Label>Maintenance mode</Label>
              <Switch
                checked={settings.maintenanceMode}
                onCheckedChange={(v) => setSettings({ ...settings, maintenanceMode: v })}
              />
            </div>
            <div className="flex flex-col gap-2">
              <Label>Maintenance message</Label>
              <Textarea
                value={settings.maintenanceMessage}
                onChange={(e) => setSettings({ ...settings, maintenanceMessage: e.target.value })}
                rows={3}
              />
            </div>
          </CardContent>
        </Card>

        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Support</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <Label>Support email</Label>
              <Input
                type="email"
                value={settings.supportEmail}
                onChange={(e) => setSettings({ ...settings, supportEmail: e.target.value })}
              />
            </div>
            <div className="flex flex-col gap-2">
              <Label>Support phone</Label>
              <Input
                value={settings.supportPhone}
                onChange={(e) => setSettings({ ...settings, supportPhone: e.target.value })}
              />
            </div>
          </CardContent>
        </Card>

        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>Matching</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <Label>Search radii (km, comma-separated)</Label>
              <Input
                value={settings.searchRadiiKm.join(', ')}
                onChange={(e) =>
                  setSettings({
                    ...settings,
                    searchRadiiKm: e.target.value.split(',').map((v) => Number(v.trim())).filter((n) => !Number.isNaN(n)),
                  })
                }
              />
            </div>
            <div className="flex flex-col gap-2">
              <Label>Candidate review window (seconds)</Label>
              <Input
                type="number"
                value={settings.candidateReviewSeconds}
                onChange={(e) => setSettings({ ...settings, candidateReviewSeconds: Number(e.target.value) })}
              />
            </div>
          </CardContent>
        </Card>

        <Card className="transition-shadow hover:shadow-sm">
          <CardHeader><CardTitle>App version</CardTitle></CardHeader>
          <CardContent className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <Label>Minimum supported app version</Label>
              <Input
                value={settings.minSupportedAppVersion}
                onChange={(e) => setSettings({ ...settings, minSupportedAppVersion: e.target.value })}
              />
            </div>
          </CardContent>
        </Card>
      </div>
    </PageScaffold>
  )
}
