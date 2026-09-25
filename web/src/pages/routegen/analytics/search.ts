import { z } from 'zod'
import type { DistributionGroupBy, DistributionSort, OutlierDirection, RunRateGroupBy } from '@/api/types'

export const BASES = ['loaded', 'gross'] as const

export type Basis = (typeof BASES)[number]

export const RUN_RATE_GROUPS = ['department', 'country', 'level'] as const satisfies readonly RunRateGroupBy[]

export const DISTRIBUTION_GROUPS = [...RUN_RATE_GROUPS, 'title'] as const satisfies readonly DistributionGroupBy[]

const DISTRIBUTION_SORTS = ['name', '-name', 'headcount', '-headcount', 'median', '-median'] as const satisfies DistributionSort[]

export const DIRECTIONS = ['below', 'above'] as const satisfies readonly OutlierDirection[]

// satisfies only checks each listed value is valid. This fails the build when the API adds one.
type Lists<All, Listed extends All> = [Exclude<All, Listed>] extends [never] ? true : false
true satisfies Lists<RunRateGroupBy, (typeof RUN_RATE_GROUPS)[number]>
true satisfies Lists<DistributionGroupBy, (typeof DISTRIBUTION_GROUPS)[number]>
true satisfies Lists<DistributionSort, (typeof DISTRIBUTION_SORTS)[number]>
true satisfies Lists<OutlierDirection, (typeof DIRECTIONS)[number]>

const ids = z.array(z.string()).optional().catch(undefined)

// Loaded by default: comparing cost across countries is why the multiplier exists.
export const overviewSearch = z.object({
  basis: z.enum(BASES).default('loaded').catch('loaded'),
  group_by: z.enum(RUN_RATE_GROUPS).default('department').catch('department'),
})

export const OVERVIEW_DEFAULTS = overviewSearch.parse({})

// No sort default in the URL: the API's default depends on group_by, see defaultDistributionSort.
export const distributionSearch = z.object({
  group_by: z.enum(DISTRIBUTION_GROUPS).default('department').catch('department'),
  department: ids,
  country: ids,
  level: ids,
  title: z.string().optional().catch(undefined),
  sort: z.enum(DISTRIBUTION_SORTS).optional().catch(undefined),
  page: z.int().min(1).default(1).catch(1),
})

export type DistributionSearch = z.output<typeof distributionSearch>

export const DISTRIBUTION_DEFAULTS = distributionSearch.parse({})

export function defaultDistributionSort(groupBy: DistributionGroupBy): DistributionSort {
  return groupBy === 'title' ? '-headcount' : 'name'
}

export const outliersSearch = z.object({
  tab: z.enum(['people', 'cohorts']).default('people').catch('people'),
  department: ids,
  country: ids,
  level: ids,
  direction: z.enum(DIRECTIONS).optional().catch(undefined),
  page: z.int().min(1).default(1).catch(1),
})

export type OutliersSearch = z.output<typeof outliersSearch>

export const OUTLIERS_DEFAULTS = outliersSearch.parse({})
