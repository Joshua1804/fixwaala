import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  LayoutDashboard, Users, ShieldCheck, Ticket, Briefcase, CreditCard,
  Flag, Siren, Star, Megaphone, Settings, Image, History, Activity, LogOut,
} from 'lucide-react'
import {
  CommandDialog, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList,
} from '@/components/ui/command'
import { routes } from '@/routes'
import { useAdminAuth } from '@/auth/AdminAuthContext'

const destinations = [
  { to: routes.dashboard, icon: LayoutDashboard, label: 'Dashboard' },
  { to: routes.users, icon: Users, label: 'Users' },
  { to: routes.admins, icon: ShieldCheck, label: 'Admins' },
  { to: routes.tickets, icon: Ticket, label: 'Tickets' },
  { to: routes.jobs, icon: Briefcase, label: 'Jobs' },
  { to: routes.payments, icon: CreditCard, label: 'Payments' },
  { to: routes.reports, icon: Flag, label: 'Reports' },
  { to: routes.safetyAlerts, icon: Siren, label: 'Safety alerts' },
  { to: routes.ratings, icon: Star, label: 'Ratings' },
  { to: routes.announcements, icon: Megaphone, label: 'Announcements' },
  { to: routes.settings, icon: Settings, label: 'Settings' },
  { to: routes.media, icon: Image, label: 'Media' },
  { to: routes.auditLog, icon: History, label: 'Audit log' },
  { to: routes.monitoring, icon: Activity, label: 'Monitoring' },
]

const CommandPaletteContext = createContext<{ open: () => void } | null>(null)

/** Exposes `open()` so any component (the sidebar search button, a keyboard shortcut) can trigger the palette. */
export function useCommandPalette() {
  const ctx = useContext(CommandPaletteContext)
  if (!ctx) throw new Error('useCommandPalette must be used within CommandPaletteProvider')
  return ctx
}

/** Global ⌘K / Ctrl+K quick navigation, standard in modern admin panels. */
export function CommandPaletteProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false)
  const navigate = useNavigate()
  const { signOut } = useAdminAuth()

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (e.key === 'k' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        setOpen((o) => !o)
      }
    }
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [])

  function go(to: string) {
    setOpen(false)
    navigate(to)
  }

  return (
    <CommandPaletteContext.Provider value={{ open: () => setOpen(true) }}>
      {children}
      <CommandDialog open={open} onOpenChange={setOpen}>
        <CommandInput placeholder="Jump to a page…" />
        <CommandList>
          <CommandEmpty>No matching page.</CommandEmpty>
          <CommandGroup heading="Navigate">
            {destinations.map((d) => (
              <CommandItem key={d.to} value={d.label} onSelect={() => go(d.to)}>
                <d.icon />
                {d.label}
              </CommandItem>
            ))}
          </CommandGroup>
          <CommandGroup heading="Account">
            <CommandItem
              value="Sign out"
              onSelect={() => {
                setOpen(false)
                signOut().then(() => navigate(routes.login))
              }}
            >
              <LogOut />
              Sign out
            </CommandItem>
          </CommandGroup>
        </CommandList>
      </CommandDialog>
    </CommandPaletteContext.Provider>
  )
}
