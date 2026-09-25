import { useEffect, useEffectEvent, useState } from 'react'
import { useWriteCount } from '@/hooks/writes'

export type ApiResult<T> = { data: T | undefined; error: unknown; loading: boolean; retry: () => void }

type Settled<T> = { requestId: string; data?: T; error?: unknown }

// Loads when key changes, and again after any write. The last data stays on screen while the next loads,
// and after a load that fails. A superseded request is aborted, so an old answer never lands last.
export function useApi<T>(
  key: unknown[],
  load: (signal: AbortSignal) => Promise<T>,
  { enabled = true } = {},
): ApiResult<T> {
  const writes = useWriteCount()
  const [retries, setRetries] = useState(0)
  const [settled, setSettled] = useState<Settled<T>>({ requestId: '' })
  const run = useEffectEvent(load)
  const requestId = JSON.stringify([key, writes, retries])

  useEffect(() => {
    if (!enabled) return

    const controller = new AbortController()
    run(controller.signal).then(
      (data) => {
        if (!controller.signal.aborted) setSettled({ requestId, data })
      },
      (error: unknown) => {
        if (!controller.signal.aborted) setSettled((last) => ({ requestId, data: last.data, error }))
      },
    )
    return () => controller.abort()
  }, [requestId, enabled])

  const current = settled.requestId === requestId

  return {
    data: settled.data,
    error: current ? settled.error : undefined,
    loading: enabled && !current,
    retry: () => setRetries((count) => count + 1),
  }
}
