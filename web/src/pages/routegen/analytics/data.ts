import { api, unwrap } from '@/api/client'
import type { RunRateGroupBy } from '@/api/types'
import type { DistributionSearch, OutliersSearch } from '@/pages/routegen/analytics/search'

export function fetchRunRate(groupBy: RunRateGroupBy, asOf: string, signal: AbortSignal) {
  return unwrap(api.GET('/api/v1/analytics/run_rate', { params: { query: { group_by: groupBy, as_of: asOf } }, signal }))
}

export async function fetchTrend(asOf: string, signal: AbortSignal) {
  const { data } = await unwrap(api.GET('/api/v1/analytics/trend', { params: { query: { as_of: asOf } }, signal }))
  return data
}

export function fetchDistribution(search: DistributionSearch, asOf: string, signal: AbortSignal) {
  return unwrap(
    api.GET('/api/v1/analytics/distribution', {
      params: {
        query: {
          group_by: search.group_by,
          'department_id[]': search.department,
          'country_id[]': search.country,
          'level_id[]': search.level,
          title: search.title,
          sort: search.sort,
          page: search.page,
          as_of: asOf,
        },
      },
      signal,
    }),
  )
}

export async function fetchCohorts(asOf: string, signal: AbortSignal) {
  const { data } = await unwrap(api.GET('/api/v1/analytics/cohorts', { params: { query: { as_of: asOf } }, signal }))
  return data
}

export function fetchOutliers(search: OutliersSearch, asOf: string, signal: AbortSignal) {
  return unwrap(
    api.GET('/api/v1/analytics/outliers', {
      params: {
        query: {
          'department_id[]': search.department,
          'country_id[]': search.country,
          'level_id[]': search.level,
          direction: search.direction,
          page: search.page,
          as_of: asOf,
        },
      },
      signal,
    }),
  )
}
