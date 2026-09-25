import type { DistributionGroupBy } from '@/api/types'
import type { Basis } from '@/pages/routegen/analytics/search'

export const GROUP_LABELS: Record<DistributionGroupBy, string> = {
  department: 'Department',
  country: 'Country',
  level: 'Level',
  title: 'Title',
}

export const BASIS_LABELS: Record<Basis, string> = { loaded: 'Fully loaded', gross: 'Gross' }

// The multiplier is not effective dated, so a past date shows past salaries at today's multipliers.
export const LOADED_NOTE = 'at current employer cost rates'
