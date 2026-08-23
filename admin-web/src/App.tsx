import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AdminAuthProvider } from '@/auth/AdminAuthContext'
import { ProtectedRoute } from '@/auth/ProtectedRoute'
import { AdminShell } from '@/components/layout/AdminShell'
import { CommandPaletteProvider } from '@/components/layout/CommandPalette'
import { Toaster } from '@/components/ui/sonner'
import { TooltipProvider } from '@/components/ui/tooltip'
import { ConfirmDialogProvider } from '@/components/shared/ConfirmDialog'
import { routes } from '@/routes'

import { LoginScreen } from '@/features/login/LoginScreen'
import { DashboardScreen } from '@/features/dashboard/DashboardScreen'
import { UserListScreen } from '@/features/users/UserListScreen'
import { UserDetailScreen } from '@/features/users/UserDetailScreen'
import { AdminsScreen } from '@/features/admins/AdminsScreen'
import { ReportListScreen } from '@/features/moderation/ReportListScreen'
import { ReportDetailScreen } from '@/features/moderation/ReportDetailScreen'
import { SafetyAlertsScreen } from '@/features/moderation/SafetyAlertsScreen'
import { SafetyAlertDetailScreen } from '@/features/moderation/SafetyAlertDetailScreen'
import { RatingsScreen } from '@/features/moderation/RatingsScreen'
import { PaymentListScreen } from '@/features/payments/PaymentListScreen'
import { PaymentDetailScreen } from '@/features/payments/PaymentDetailScreen'
import { TicketListScreen } from '@/features/tickets-jobs/TicketListScreen'
import { TicketDetailScreen } from '@/features/tickets-jobs/TicketDetailScreen'
import { JobListScreen } from '@/features/tickets-jobs/JobListScreen'
import { JobDetailScreen } from '@/features/tickets-jobs/JobDetailScreen'
import { AnnouncementsScreen } from '@/features/content/AnnouncementsScreen'
import { PlatformSettingsScreen } from '@/features/settings/PlatformSettingsScreen'
import { MediaScreen } from '@/features/media/MediaScreen'
import { AuditLogScreen } from '@/features/audit/AuditLogScreen'
import { MonitoringScreen } from '@/features/monitoring/MonitoringScreen'

function Shell({ children }: { children: React.ReactNode }) {
  return (
    <ProtectedRoute>
      <CommandPaletteProvider>
        <AdminShell>{children}</AdminShell>
      </CommandPaletteProvider>
    </ProtectedRoute>
  )
}

function App() {
  return (
    <BrowserRouter>
      <AdminAuthProvider>
        <TooltipProvider>
        <ConfirmDialogProvider>
          <Toaster position="top-right" richColors closeButton />
          <Routes>
            <Route path={routes.login} element={<LoginScreen />} />

            <Route path={routes.dashboard} element={<Shell><DashboardScreen /></Shell>} />

            <Route path={routes.users} element={<Shell><UserListScreen /></Shell>} />
            <Route path={routes.userDetail} element={<Shell><UserDetailScreen /></Shell>} />

            <Route path={routes.admins} element={<Shell><AdminsScreen /></Shell>} />

            <Route path={routes.tickets} element={<Shell><TicketListScreen /></Shell>} />
            <Route path={routes.ticketDetail} element={<Shell><TicketDetailScreen /></Shell>} />
            <Route path={routes.jobs} element={<Shell><JobListScreen /></Shell>} />
            <Route path={routes.jobDetail} element={<Shell><JobDetailScreen /></Shell>} />
            <Route path={routes.payments} element={<Shell><PaymentListScreen /></Shell>} />
            <Route path={routes.paymentDetail} element={<Shell><PaymentDetailScreen /></Shell>} />

            <Route path={routes.reports} element={<Shell><ReportListScreen /></Shell>} />
            <Route path={routes.reportDetail} element={<Shell><ReportDetailScreen /></Shell>} />
            <Route path={routes.safetyAlerts} element={<Shell><SafetyAlertsScreen /></Shell>} />
            <Route path={routes.safetyAlertDetail} element={<Shell><SafetyAlertDetailScreen /></Shell>} />
            <Route path={routes.ratings} element={<Shell><RatingsScreen /></Shell>} />

            <Route path={routes.announcements} element={<Shell><AnnouncementsScreen /></Shell>} />
            <Route path={routes.settings} element={<Shell><PlatformSettingsScreen /></Shell>} />

            <Route path={routes.media} element={<Shell><MediaScreen /></Shell>} />
            <Route path={routes.auditLog} element={<Shell><AuditLogScreen /></Shell>} />
            <Route path={routes.monitoring} element={<Shell><MonitoringScreen /></Shell>} />

            <Route path="/" element={<Navigate to={routes.dashboard} replace />} />
            <Route path="*" element={<Navigate to={routes.dashboard} replace />} />
          </Routes>
        </ConfirmDialogProvider>
        </TooltipProvider>
      </AdminAuthProvider>
    </BrowserRouter>
  )
}

export default App
