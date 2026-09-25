import { http, HttpResponse } from 'msw'
import { describe, expect, it, onTestFinished, vi } from 'vitest'
import { api, unwrap } from '@/api/client'
import { ApiError, NetworkError } from '@/api/errors'
import { signOut } from '@/auth/auth'
import { useSession } from '@/auth/session'
import { tokens, user } from '@/test/fixtures'
import { apiError, server, url } from '@/test/server'

function countRefreshes(reply: (token: string) => Response | Promise<Response>) {
  const spent: string[] = []
  server.use(
    http.post(url('/auth/refresh'), async ({ request }) => {
      const { refresh_token } = (await request.json()) as { refresh_token: string }
      spent.push(refresh_token)
      return reply(refresh_token)
    }),
  )
  return spent
}

function meAnswers(accessToken: string) {
  server.use(
    http.get(url('/me'), ({ request }) =>
      request.headers.get('Authorization') === `Bearer ${accessToken}`
        ? HttpResponse.json(user)
        : apiError(401, 'token_expired', 'Access token has expired'),
    ),
  )
}

const me = () => unwrap(api.GET('/api/v1/me'))

describe('transport', () => {
  it('refreshes before the first request when there is no access token', async () => {
    useSession.setState({ refreshToken: 'refresh-stored' })
    const spent = countRefreshes(() => HttpResponse.json(tokens('new')))
    meAnswers('access-new')

    await expect(me()).resolves.toEqual(user)
    expect(spent).toEqual(['refresh-stored'])
    expect(useSession.getState().refreshToken).toBe('refresh-new')
  })

  it('refreshes once for concurrent requests', async () => {
    useSession.setState({ refreshToken: 'refresh-stored' })
    const spent = countRefreshes(() => HttpResponse.json(tokens('new')))
    meAnswers('access-new')

    await Promise.all([me(), me(), me()])
    expect(spent).toHaveLength(1)
  })

  it('refreshes before a token that is about to expire', async () => {
    useSession.setState({ accessToken: 'access-old', expiresAt: Date.now() + 10_000, refreshToken: 'refresh-old' })
    const spent = countRefreshes(() => HttpResponse.json(tokens('new')))
    meAnswers('access-new')

    await me()
    expect(spent).toEqual(['refresh-old'])
  })

  it('refreshes and retries once when the API says the token expired', async () => {
    useSession.getState().start(tokens('old'))
    const spent = countRefreshes(() => HttpResponse.json(tokens('new')))
    meAnswers('access-new')

    await expect(me()).resolves.toEqual(user)
    expect(spent).toEqual(['refresh-old'])
  })

  it('waits for another tab to refresh, then spends the token it left', async () => {
    let release = () => {}
    const otherTab = new Promise<void>((resolve) => (release = resolve))
    Object.defineProperty(navigator, 'locks', {
      configurable: true,
      value: {
        request: async (_name: string, task: () => Promise<string>) => {
          await otherTab
          return task()
        },
      },
    })
    onTestFinished(() => void Reflect.deleteProperty(navigator, 'locks'))
    useSession.setState({ refreshToken: 'refresh-old' })
    const spent = countRefreshes(() => HttpResponse.json(tokens('new')))
    meAnswers('access-new')

    const request = me()
    localStorage.setItem('sms-session', JSON.stringify({ state: { refreshToken: 'refresh-other-tab' }, version: 0 }))
    release()
    await request
    expect(spent).toEqual(['refresh-other-tab'])
  })

  it('ends the session when the refresh is refused', async () => {
    useSession.setState({ refreshToken: 'refresh-spent' })
    countRefreshes(() => apiError(401, 'invalid_refresh_token', 'Refresh token is expired or has already been used'))

    await expect(me()).rejects.toMatchObject({ status: 401, code: 'invalid_refresh_token' })
    expect(useSession.getState().refreshToken).toBeNull()
  })

  it.each([429, 503])('keeps the session when the refresh answers %i', async (status) => {
    useSession.setState({ refreshToken: 'refresh-stored' })
    countRefreshes(() => apiError(status, 'unavailable', 'Try again'))

    await expect(me()).rejects.toBeInstanceOf(ApiError)
    expect(useSession.getState().refreshToken).toBe('refresh-stored')
  })

  it('stays signed out when a refresh lands after the sign out', async () => {
    useSession.setState({ refreshToken: 'refresh-stored' })
    let answer = () => {}
    const answered = new Promise<void>((resolve) => (answer = resolve))
    const spent = countRefreshes(() => answered.then(() => HttpResponse.json(tokens('late'))))

    const request = me()
    await vi.waitFor(() => expect(spent).toHaveLength(1))
    useSession.getState().end()
    answer()
    await expect(request).rejects.toMatchObject({ status: 401 })
    expect(useSession.getState().refreshToken).toBeNull()
  })

  it('names a request that got no answer a network error', async () => {
    useSession.getState().start(tokens('old'))
    server.use(http.get(url('/me'), () => HttpResponse.error()))

    await expect(me()).rejects.toBeInstanceOf(NetworkError)
  })

  it('ends the session on any other 401', async () => {
    useSession.getState().start(tokens('old'))
    server.use(http.get(url('/me'), () => apiError(401, 'invalid_token', 'Access token is missing or invalid')))

    await expect(me()).rejects.toMatchObject({ status: 401, code: 'invalid_token' })
    expect(useSession.getState().refreshToken).toBeNull()
  })

  it('signs out locally even when the API cannot be reached', async () => {
    useSession.getState().start(tokens('old'))
    server.use(http.delete(url('/auth/sign_out'), () => HttpResponse.error()))

    await signOut()
    expect(useSession.getState()).toMatchObject({ accessToken: null, refreshToken: null })
    expect(JSON.parse(localStorage.getItem('sms-session') ?? '{}').state.refreshToken).toBeNull()
  })
})
