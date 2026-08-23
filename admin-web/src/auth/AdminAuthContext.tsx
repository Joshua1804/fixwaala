import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
} from 'firebase/auth'
import { auth } from '@/lib/firebase'

export type AdminAuthState =
  | { status: 'checking' }
  | { status: 'signedOut' }
  | { status: 'forbidden'; email: string }
  | { status: 'signedIn'; email: string; uid: string }

/**
 * Thrown by signIn() when the credentials are valid but the account does not
 * hold the `admin` claim. The claim can only be granted by
 * scripts/admin/grant_admin_claim.js — nothing client-side can set it.
 */
export class AdminAccessDeniedError extends Error {}

interface AdminAuthContextValue {
  state: AdminAuthState
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
}

const AdminAuthContext = createContext<AdminAuthContextValue | null>(null)

export function AdminAuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AdminAuthState>({ status: 'checking' })

  useEffect(() => {
    return onAuthStateChanged(auth, async (user) => {
      if (!user) {
        setState({ status: 'signedOut' })
        return
      }
      // Force-refresh so a claim granted/revoked elsewhere is picked up on
      // the next auth event, notably right after signIn().
      const result = await user.getIdTokenResult(true)
      if (result.claims?.admin === true) {
        setState({ status: 'signedIn', email: user.email ?? '', uid: user.uid })
      } else {
        setState({ status: 'forbidden', email: user.email ?? '' })
      }
    })
  }, [])

  async function signIn(email: string, password: string) {
    const credential = await signInWithEmailAndPassword(auth, email.trim(), password)
    const result = await credential.user.getIdTokenResult(true)
    if (result.claims?.admin !== true) {
      // Don't leave a non-admin session sitting authenticated against the admin app.
      await firebaseSignOut(auth)
      throw new AdminAccessDeniedError(
        'This account does not have admin access. Ask an existing admin to ' +
          'run scripts/admin/grant_admin_claim.js for this email.',
      )
    }
  }

  async function signOut() {
    await firebaseSignOut(auth)
  }

  return (
    <AdminAuthContext.Provider value={{ state, signIn, signOut }}>
      {children}
    </AdminAuthContext.Provider>
  )
}

export function useAdminAuth() {
  const ctx = useContext(AdminAuthContext)
  if (!ctx) throw new Error('useAdminAuth must be used within AdminAuthProvider')
  return ctx
}
