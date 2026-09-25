import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import type { TokenPair } from '@/api/types'

const STORAGE_KEY = 'sms-session'

type Session = {
  accessToken: string | null
  expiresAt: number | null
  refreshToken: string | null
  start: (tokens: TokenPair) => void
  end: () => void
}

export const useSession = create<Session>()(
  persist(
    (set) => ({
      accessToken: null,
      expiresAt: null,
      refreshToken: null,
      start: (tokens) =>
        set({
          accessToken: tokens.access_token,
          expiresAt: Date.now() + tokens.expires_in * 1000,
          refreshToken: tokens.refresh_token,
        }),
      end: () => set({ accessToken: null, expiresAt: null, refreshToken: null }),
    }),
    {
      name: STORAGE_KEY,
      // The access token stays in memory. A reload spends the refresh token for a new one.
      partialize: ({ refreshToken }) => ({ refreshToken }),
    },
  ),
)

// Another tab signed in, rotated the refresh token, or signed out.
export function syncSessionAcrossTabs() {
  window.addEventListener('storage', (event) => {
    if (event.key !== STORAGE_KEY) return

    void useSession.persist.rehydrate()?.then(() => {
      if (!useSession.getState().refreshToken) useSession.getState().end()
    })
  })
}
