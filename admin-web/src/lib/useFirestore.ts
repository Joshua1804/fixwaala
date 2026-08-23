import { useEffect, useState } from 'react'
import {
  onSnapshot,
  type DocumentData,
  type FirestoreError,
  type Query,
  type DocumentReference,
} from 'firebase/firestore'

interface QueryState<T> {
  data: T[]
  loading: boolean
  error: FirestoreError | null
}

/**
 * Subscribes to a Firestore query in real time, mapping each doc with `mapper`.
 *
 * `query` must be a stable reference (wrap it in `useMemo` at the call site) —
 * a fresh `Query` object built inline on every render will re-run this
 * effect every render, since Firestore query objects have no referential
 * equality across separate `query(...)` calls, causing an infinite update
 * loop.
 */
export function useCollection<T>(
  query: Query<DocumentData> | null,
  mapper: (id: string, data: DocumentData) => T,
): QueryState<T> {
  const [state, setState] = useState<QueryState<T>>({ data: [], loading: true, error: null })

  useEffect(() => {
    if (!query) {
      setState({ data: [], loading: false, error: null })
      return
    }
    setState((s) => ({ ...s, loading: true }))
    const unsub = onSnapshot(
      query,
      (snap) => {
        setState({ data: snap.docs.map((d) => mapper(d.id, d.data())), loading: false, error: null })
      },
      (error) => setState({ data: [], loading: false, error }),
    )
    return unsub
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [query])

  return state
}

interface DocState<T> {
  data: T | null
  loading: boolean
  error: FirestoreError | null
}

/** Subscribes to a single Firestore document in real time. */
export function useDocument<T>(
  ref: DocumentReference<DocumentData> | null,
  mapper: (id: string, data: DocumentData) => T,
): DocState<T> {
  const [state, setState] = useState<DocState<T>>({ data: null, loading: true, error: null })

  useEffect(() => {
    if (!ref) {
      setState({ data: null, loading: false, error: null })
      return
    }
    setState((s) => ({ ...s, loading: true }))
    const unsub = onSnapshot(
      ref,
      (snap) => {
        setState({
          data: snap.exists() ? mapper(snap.id, snap.data()) : null,
          loading: false,
          error: null,
        })
      },
      (error) => setState({ data: null, loading: false, error }),
    )
    return unsub
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ref?.path])

  return state
}
