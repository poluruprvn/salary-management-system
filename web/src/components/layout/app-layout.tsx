import { type ErrorComponentProps, Link, Navigate, Outlet, useRouter, useRouterState } from '@tanstack/react-router'
import { useSession } from '@/auth/session'
import { ErrorPanel } from '@/components/error-panel'
import { AsOfPicker } from '@/components/layout/as-of-picker'
import { UserMenu } from '@/components/layout/user-menu'

const NAV = [
  { to: '/analytics', label: 'Analytics' },
  { to: '/employees', label: 'Employees' },
  { to: '/settings/countries', label: 'Settings' },
] as const

// The session can end under a mounted page: a sign out, a refused refresh, or a sign out in another tab.
export function AppLayout() {
  const signedIn = useSession((session) => session.refreshToken !== null)
  // The page on screen, not the pending location. On the way to sign in, the pending one is sign in itself,
  // and redirecting back to it would nest the redirect forever.
  const href = useRouterState({ select: (state) => (state.resolvedLocation ?? state.location).href })

  if (!signedIn) return <Navigate to="/sign-in" search={{ redirect: href }} replace />

  return (
    <div className="min-h-svh">
      <header className="sticky top-0 z-40 border-b bg-background">
        <div className="mx-auto flex h-14 max-w-7xl items-center gap-6 px-4 sm:px-6">
          <Link to="/analytics" className="flex items-center gap-2 font-heading text-sm font-semibold">
            <img src="/favicon.svg" alt="" className="size-6" />
            <span className="hidden sm:inline">Salary management</span>
          </Link>
          <nav className="flex items-center gap-1 text-sm">
            {NAV.map((item) => (
              <Link
                key={item.to}
                to={item.to}
                activeOptions={{ includeSearch: false }}
                className="rounded-md px-2 py-1 transition-colors hover:text-foreground"
                activeProps={{ className: 'font-medium text-foreground' }}
                inactiveProps={{ className: 'text-muted-foreground' }}
              >
                {item.label}
              </Link>
            ))}
          </nav>
          <div className="ml-auto flex items-center gap-2">
            <AsOfPicker />
            <UserMenu />
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
        <Outlet />
      </main>
    </div>
  )
}

// invalidate, not reset. reset only clears the boundary, and a failed loader stays failed until it runs again.
export function AppError({ error }: ErrorComponentProps) {
  const router = useRouter()

  return (
    <div className="mx-auto max-w-lg p-6">
      <ErrorPanel title="Could not start the app" error={error} onRetry={() => void router.invalidate()} />
    </div>
  )
}
