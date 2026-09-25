import { getRouteApi, useSearch } from '@tanstack/react-router'
import { api, unwrap } from '@/api/client'

// What every screen reads. The app route's loader fetches it before any page renders.
export async function loadAppData() {
  const [meta, me, countries, departments, levels] = await Promise.all([
    unwrap(api.GET('/api/v1/meta')),
    unwrap(api.GET('/api/v1/me')),
    unwrap(api.GET('/api/v1/countries')),
    unwrap(api.GET('/api/v1/departments')),
    unwrap(api.GET('/api/v1/levels')),
  ])

  return { meta, me, countries: countries.data, departments: departments.data, levels: levels.data }
}

const appRoute = getRouteApi('/app')

export function useMeta() {
  return appRoute.useLoaderData().meta
}

export function useMe() {
  return appRoute.useLoaderData().me
}

export function useClosedSets() {
  const { countries, departments, levels } = appRoute.useLoaderData()
  return { countries, departments, levels }
}

// Without as_of in the URL the date is the server's today, never the browser's: the server is on UTC.
export function useAsOf() {
  const { as_of } = useSearch({ strict: false })
  const { today } = useMeta()

  return { asOf: as_of ?? today, today }
}
