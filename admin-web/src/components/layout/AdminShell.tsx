import type { ReactNode } from 'react'
import { NavLink, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard,
  Users,
  ShieldCheck,
  Ticket,
  Briefcase,
  CreditCard,
  Flag,
  Siren,
  Star,
  Megaphone,
  Settings,
  Image,
  History,
  Activity,
  Wrench,
  LogOut,
  Search,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { routes } from '@/routes'
import { useAdminAuth } from '@/auth/AdminAuthContext'
import { useCommandPalette } from '@/components/layout/CommandPalette'

interface NavItem {
  to: string
  icon: typeof LayoutDashboard
  label: string
}

interface NavSection {
  title: string
  items: NavItem[]
}

const sections: NavSection[] = [
  { title: 'Overview', items: [{ to: routes.dashboard, icon: LayoutDashboard, label: 'Dashboard' }] },
  {
    title: 'Platform',
    items: [
      { to: routes.users, icon: Users, label: 'Users' },
      { to: routes.admins, icon: ShieldCheck, label: 'Admins' },
    ],
  },
  {
    title: 'Marketplace',
    items: [
      { to: routes.tickets, icon: Ticket, label: 'Tickets' },
      { to: routes.jobs, icon: Briefcase, label: 'Jobs' },
      { to: routes.payments, icon: CreditCard, label: 'Payments' },
    ],
  },
  {
    title: 'Trust & safety',
    items: [
      { to: routes.reports, icon: Flag, label: 'Reports' },
      { to: routes.safetyAlerts, icon: Siren, label: 'Safety alerts' },
      { to: routes.ratings, icon: Star, label: 'Ratings' },
    ],
  },
  {
    title: 'Content',
    items: [
      { to: routes.announcements, icon: Megaphone, label: 'Announcements' },
      { to: routes.settings, icon: Settings, label: 'Settings' },
    ],
  },
  {
    title: 'System',
    items: [
      { to: routes.media, icon: Image, label: 'Media' },
      { to: routes.auditLog, icon: History, label: 'Audit log' },
      { to: routes.monitoring, icon: Activity, label: 'Monitoring' },
    ],
  },
]

export function AdminShell({ children }: { children: ReactNode }) {
  const { state, signOut } = useAdminAuth()
  const navigate = useNavigate()
  const { open: openCommandPalette } = useCommandPalette()
  const email = state.status === 'signedIn' ? state.email : ''

  async function handleSignOut() {
    await signOut()
    navigate(routes.login, { replace: true })
  }

  return (
    <div className="flex min-h-screen">
      <aside className="flex w-60 shrink-0 flex-col border-r border-border bg-card">
        <div className="flex items-center gap-2.5 px-5 py-6">
          <Wrench className="h-5 w-5 text-primary transition-transform duration-500 ease-out hover:rotate-12" />
          <span className="text-base font-semibold text-foreground">Fixwaala Admin</span>
        </div>

        <div className="px-3 pb-2">
          <button
            type="button"
            onClick={openCommandPalette}
            className="flex w-full items-center gap-2 rounded-[10px] border border-border bg-background px-3 py-2 text-sm text-muted-foreground transition-colors hover:border-primary/30 hover:bg-muted"
          >
            <Search className="h-3.5 w-3.5" />
            <span className="flex-1 text-left">Search…</span>
            <kbd className="rounded border border-border bg-card px-1.5 py-0.5 font-mono text-[10px]">⌘K</kbd>
          </button>
        </div>

        <nav className="flex-1 overflow-y-auto px-3">
          {sections.map((section) => (
            <div key={section.title} className="mb-1">
              <p className="px-3 pt-4 pb-1.5 text-[11px] font-semibold tracking-wide text-muted-foreground uppercase">
                {section.title}
              </p>
              {section.items.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  className={({ isActive }) =>
                    cn(
                      'group relative mb-0.5 flex items-center gap-3 rounded-[10px] px-3 py-2.5 text-sm transition-all duration-150',
                      isActive
                        ? 'bg-primary/10 font-semibold text-primary'
                        : 'text-foreground hover:translate-x-0.5 hover:bg-muted',
                    )
                  }
                >
                  {({ isActive }) => (
                    <>
                      {isActive && (
                        <span className="absolute top-1/2 left-0 h-4 w-0.5 -translate-y-1/2 rounded-full bg-primary" />
                      )}
                      <item.icon className="h-[18px] w-[18px] transition-transform group-hover:scale-110" />
                      {item.label}
                    </>
                  )}
                </NavLink>
              ))}
            </div>
          ))}
        </nav>

        <div className="border-t border-border p-4">
          <div className="flex items-center gap-2">
            <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary/15 text-sm font-bold text-primary">
              {email ? email[0]!.toUpperCase() : '?'}
            </div>
            <span className="flex-1 truncate text-sm text-foreground">{email}</span>
            <button
              type="button"
              onClick={handleSignOut}
              title="Sign out"
              className="rounded-md p-1.5 text-muted-foreground hover:bg-muted hover:text-foreground"
            >
              <LogOut className="h-[18px] w-[18px]" />
            </button>
          </div>
        </div>
      </aside>

      <main className="flex-1 overflow-y-auto bg-background">{children}</main>
    </div>
  )
}
