import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { useAdminAuth } from './AdminAuthContext'

export function ProtectedRoute({ children }: { children: ReactNode }) {
  const { state } = useAdminAuth()

  if (state.status === 'checking') {
    return (
      <div className="flex min-h-screen items-center justify-center text-muted-foreground">
        Checking admin access…
      </div>
    )
  }

  if (state.status === 'signedOut' || state.status === 'forbidden') {
    return <Navigate to="/login" replace />
  }

  return <>{children}</>
}
