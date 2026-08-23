import { toast } from 'sonner'

/** Thin wrapper so every mutation across the app reports success/failure the same way. */
export const notify = {
  success: (message: string) => toast.success(message),
  error: (message: string) => toast.error(message),
  promise: <T,>(
    promise: Promise<T>,
    messages: { loading: string; success: string; error: string },
  ) => toast.promise(promise, messages),
}
