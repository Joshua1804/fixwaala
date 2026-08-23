import { useState, type FormEvent } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { Wrench, AlertCircle } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { AdminAccessDeniedError, useAdminAuth } from '@/auth/AdminAuthContext'

function friendlyMessage(raw: string): string {
  if (
    raw.includes('invalid-credential') ||
    raw.includes('wrong-password') ||
    raw.includes('user-not-found')
  ) {
    return 'Incorrect email or password.'
  }
  if (raw.includes('too-many-requests')) {
    return 'Too many attempts. Wait a moment and try again.'
  }
  if (raw.includes('network-request-failed')) {
    return 'Could not reach Firebase. Check your connection.'
  }
  return raw
}

export function LoginScreen() {
  const { state, signIn } = useAdminAuth()
  const location = useLocation()
  const deniedEmail = state.status === 'forbidden' ? state.email : undefined

  const [email, setEmail] = useState(deniedEmail ?? '')
  const [password, setPassword] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(
    deniedEmail
      ? `${deniedEmail} does not have admin access. Ask an existing admin to grant it — see scripts/admin/README.md.`
      : null,
  )

  if (state.status === 'signedIn') {
    const from = (location.state as { from?: string } | null)?.from ?? '/dashboard'
    return <Navigate to={from} replace />
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setSubmitting(true)
    setError(null)
    try {
      await signIn(email, password)
    } catch (err) {
      if (err instanceof AdminAccessDeniedError) {
        setError(err.message)
      } else {
        setError(friendlyMessage(err instanceof Error ? err.message : String(err)))
      }
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-background p-6">
      <div className="w-full max-w-sm">
        <form onSubmit={handleSubmit} className="flex flex-col gap-6">
          <div className="flex flex-col items-center gap-2 text-center">
            <Wrench className="h-10 w-10 text-primary" />
            <h1 className="text-2xl font-semibold text-foreground">Fixwaala Admin</h1>
            <p className="text-sm text-muted-foreground">
              Sign in with an account that has admin access.
            </p>
          </div>

          {error && (
            <div className="flex items-start gap-2 rounded-xl border border-destructive/30 bg-destructive/8 p-3 text-sm text-destructive">
              <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          <div className="flex flex-col gap-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              autoComplete="username"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </div>

          <div className="flex flex-col gap-2">
            <Label htmlFor="password">Password</Label>
            <Input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
          </div>

          <Button type="submit" disabled={submitting}>
            {submitting ? 'Signing in…' : 'Sign in'}
          </Button>

          <p className="text-center text-xs text-muted-foreground">
            No admin accounts yet? Grant the first one with
            scripts/admin/grant_admin_claim.js.
          </p>
        </form>
      </div>
    </div>
  )
}
