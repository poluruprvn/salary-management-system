import { api, unwrap } from '@/api/client'
import { publicApi } from '@/api/transport'
import { useSession } from '@/auth/session'

export async function signIn(email: string, password: string): Promise<void> {
  useSession.getState().start(await unwrap(publicApi.POST('/api/v1/auth/sign_in', { body: { email, password } })))
}

// A failed call leaves the refresh row to expire on the server, but this browser no longer holds its token.
export async function signOut(): Promise<void> {
  await api.DELETE('/api/v1/auth/sign_out').catch(() => undefined)
  useSession.getState().end()
}
