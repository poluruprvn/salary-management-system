import {
  createRootRoute,
  createRoute,
  createRouter,
  Link,
  Outlet,
  redirect,
  retainSearchParams,
  type RouterHistory,
  stripSearchParams,
} from '@tanstack/react-router'
import { z } from 'zod'
import { ApiError } from '@/api/errors'
import { useSession } from '@/auth/session'
import { AppError, AppLayout } from '@/components/layout/app-layout'
import { Spinner } from '@/components/ui/spinner'
import { loadAppData } from '@/data/app'
import { EmployeePage } from '@/pages/routegen/employees/[employeeId]/index.page'
import { EmployeesPage } from '@/pages/routegen/employees/index.page'
import { NewEmployeePage } from '@/pages/routegen/employees/new/index.page'
import {
  EMPLOYEE_DEFAULTS,
  EMPLOYEE_LIST_DEFAULTS,
  employeeListSearch,
  employeeSearch,
} from '@/pages/routegen/employees/search'
import { SignInPage } from '@/pages/sign-in'

const rootRoute = createRootRoute({
  component: Outlet,
  notFoundComponent: () => (
    <div className="mx-auto flex max-w-md flex-col items-center gap-3 py-24 text-center">
      <h1 className="font-heading text-lg font-semibold">Nothing here</h1>
      <p className="text-sm text-muted-foreground">That page does not exist.</p>
      <Link to="/employees" className="text-sm underline underline-offset-4">
        Go to employees
      </Link>
    </div>
  ),
})

const signInRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: 'sign-in',
  validateSearch: z.object({ redirect: z.string().optional().catch(undefined) }),
  component: SignInPage,
})

const appRoute = createRoute({
  getParentRoute: () => rootRoute,
  id: 'app',
  validateSearch: z.object({ as_of: z.iso.date().optional().catch(undefined) }),
  search: { middlewares: [retainSearchParams(['as_of'])] },
  beforeLoad: ({ location }) => {
    if (!useSession.getState().refreshToken) throw redirect({ to: '/sign-in', search: { redirect: location.href } })
  },
  loader: async ({ location }) => {
    try {
      return await loadAppData()
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        throw redirect({ to: '/sign-in', search: { redirect: location.href } })
      }
      throw error
    }
  },
  // Kept for an hour, so the server's today moves on in a tab left open overnight. gcTime 0 drops it at sign out,
  // so the next manager to sign in never sees the last one's name.
  staleTime: 60 * 60 * 1000,
  gcTime: 0,
  pendingComponent: () => (
    <div className="grid min-h-svh place-items-center">
      <Spinner className="size-6 text-muted-foreground" />
    </div>
  ),
  errorComponent: AppError,
  component: AppLayout,
})

const indexRoute = createRoute({
  getParentRoute: () => appRoute,
  path: '/',
  beforeLoad: () => {
    throw redirect({ to: '/employees' })
  },
})

const employeesRoute = createRoute({
  getParentRoute: () => appRoute,
  path: 'employees',
  validateSearch: employeeListSearch,
  search: { middlewares: [stripSearchParams(EMPLOYEE_LIST_DEFAULTS)] },
  component: EmployeesPage,
})

const newEmployeeRoute = createRoute({
  getParentRoute: () => appRoute,
  path: 'employees/new',
  component: NewEmployeePage,
})

const employeeRoute = createRoute({
  getParentRoute: () => appRoute,
  path: 'employees/$employeeId',
  validateSearch: employeeSearch,
  search: { middlewares: [stripSearchParams(EMPLOYEE_DEFAULTS)] },
  component: EmployeePage,
})

const routeTree = rootRoute.addChildren([
  signInRoute,
  appRoute.addChildren([indexRoute, employeesRoute, newEmployeeRoute, employeeRoute]),
])

export function createAppRouter(history?: RouterHistory) {
  return createRouter({ routeTree, history, scrollRestoration: true })
}

declare module '@tanstack/react-router' {
  interface Register {
    router: ReturnType<typeof createAppRouter>
  }
}
