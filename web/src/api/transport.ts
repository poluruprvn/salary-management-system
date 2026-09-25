import createClient from 'openapi-fetch'
import { ApiError, isErrorBody, NetworkError } from '@/api/errors'
import type { paths } from '@/api/schema'
import { useSession } from '@/auth/session'

export const API_URL = import.meta.env.VITE_API_URL ?? 'http://localhost:3000'

// Refreshing this early means no request leaves with a token that lapses on the way.
const EXPIRY_MARGIN_MS = 30_000

export async function authorizedFetch(request: Request): Promise<Response> {
  // Sending consumes the body, and a retry needs one of its own.
  const retry = request.clone()
  let response = await send(request, await currentAccessToken())

  if (response.status === 401 && (await errorCode(response)) === 'token_expired') {
    response = await send(retry, await refreshAccessToken())
  }
  if (response.status === 401) useSession.getState().end()

  return response
}

function publicFetch(request: Request): Promise<Response> {
  return send(request, null)
}

// fetch rejects with a TypeError only when no answer came back. Any other TypeError is a bug, not the network.
function send(request: Request, token: string | null): Promise<Response> {
  if (token) request.headers.set('Authorization', `Bearer ${token}`)

  return fetch(request).catch((cause: unknown) => {
    throw cause instanceof TypeError ? new NetworkError(cause.message) : cause
  })
}

async function errorCode(response: Response): Promise<string | undefined> {
  const body: unknown = await response
    .clone()
    .json()
    .catch(() => undefined)

  return isErrorBody(body) ? body.error.code : undefined
}

async function currentAccessToken(): Promise<string | null> {
  const { accessToken, expiresAt, refreshToken } = useSession.getState()
  if (accessToken && expiresAt !== null && expiresAt - EXPIRY_MARGIN_MS > Date.now()) return accessToken

  return refreshToken ? refreshAccessToken() : null
}

// For calls made without a session: sign in, and the refresh itself, so a refresh never waits on a refresh.
export const publicApi = createClient<paths>({ baseUrl: API_URL, fetch: publicFetch })

let refreshing: Promise<string> | null = null

// Concurrent requests share one refresh. A second would spend a token the first already rotated.
function refreshAccessToken(): Promise<string> {
  refreshing ??= withRefreshLock(rotate).finally(() => {
    refreshing = null
  })

  return refreshing
}

// Tabs share the refresh token, so they take turns spending it.
function withRefreshLock(task: () => Promise<string>): Promise<string> {
  return 'locks' in navigator ? navigator.locks.request('sms-refresh', task) : task()
}

async function rotate(): Promise<string> {
  // Another tab may have rotated the token while this one waited for the lock.
  await useSession.persist.rehydrate()
  const { refreshToken, start, end } = useSession.getState()
  if (!refreshToken) {
    end()
    throw new ApiError(401, undefined)
  }

  const { data, error, response } = await publicApi.POST('/api/v1/auth/refresh', {
    body: { refresh_token: refreshToken },
  })
  if (!data) {
    // Only the API's refusal ends the session. A 5xx, or a proxy's 429, says nothing about the token.
    if (response.status === 401) end()
    throw new ApiError(response.status, error)
  }

  // A sign out while this was in flight wins, in this tab or another.
  if (!useSession.getState().refreshToken) throw new ApiError(401, undefined)

  start(data)
  return data.access_token
}
