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
import { DistributionPage } from '@/pages/routegen/analytics/distribution/index.page'
import { AnalyticsPage } from '@/pages/routegen/analytics/index.page'
import { OutliersPage } from '@/pages/routegen/analytics/outliers/index.page'
import {
  DISTRIBUTION_DEFAULTS,
  distributionSearch,
  OUTLIERS_DEFAULTS,
  OVERVIEW_DEFAULTS,
  outliersSearch,
  overviewSearch,
} from '@/pages/routegen/analytics/search'
import { EmployeePage } from '@/pages/routegen/employees/[employeeId]/index.page'
import { EmployeesPage } from '@/pages/routegen/employees/index.page'
import { NewEmployeePage } from '@/pages/routegen/employees/new/index.page'
import {
  EMPLOYEE_DEFAULTS,
  EMPLOYEE_LIST_DEFAULTS,
  employeeListSearch,
  employeeSearch,
} from '@/pages/routegen/employees/search'
import { CountriesPage } from '@/pages/routegen/settings/countries/index.page'
import { SignInPage } from '@/pages/sign-in'

const rootRoute = createRootRoute({
  component: Outlet,
  notFoundComponent: () => (
    <div className="mx-auto flex max-w-md flex-col items-center gap-3 py-24 text-center">
      <h1 className="font-heading text-lg font-semibold">Nothing here</h1>
      <p className="text-sm text-muted-foreground">That page does not exist.</p>
      <Link to="/analytics" className="text-sm underline underline-offset-4">
        Go to analytics
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
    throw redirect({ to: '/analytics' })
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

const analyticsRoute = createRoute({
  getParentRoute: () => appRoute,
  path: 'analytics',
  validateSearch: overviewSearch,
  search: { middlewares: [stripSearchParams(OVERVIEW_DEFAULTS)] },
  component: AnalyticsPage,
})

const distributionRoute = createRoute({
  getParentRoute: () => appRoute,
  path: 'analytics/distribution',
  validateSearch: distributionSearch,
  search: { middlewares: [stripSearchParams(DISTRIBUTION_DEFAULTS)] },
  component: DistributionPage,
})

const outliersRoute = createRoute({
  getParentRoute: () => appRoute,
  path: 'analytics/outliers',
  validateSearch: outliersSearch,
  search: { middlewares: [stripSearchParams(OUTLIERS_DEFAULTS)] },
  component: OutliersPage,
})

const countriesRoute = createRoute({
  getParentRoute: () => appRoute,
  path: 'settings/countries',
  component: CountriesPage,
})

const routeTree = rootRoute.addChildren([
  signInRoute,
  appRoute.addChildren([
    indexRoute,
    employeesRoute,
    newEmployeeRoute,
    employeeRoute,
    analyticsRoute,
    distributionRoute,
    outliersRoute,
    countriesRoute,
  ]),
])

export function createAppRouter(history?: RouterHistory) {
  return createRouter({ routeTree, history, scrollRestoration: true })
}

declare module '@tanstack/react-router' {
  interface Register {
    router: ReturnType<typeof createAppRouter>
  }
}
