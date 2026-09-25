import type {
  Audit,
  Cohort,
  Country,
  Department,
  DistributionRow,
  Employee,
  Level,
  Meta,
  Outlier,
  Pagination,
  RunRate,
  RunRateGroupBy,
  SalaryHistoryEntry,
  TitleCount,
  TokenPair,
  TrendPoint,
  User,
} from '@/api/types'

export const meta: Meta = {
  base_currency: 'USD',
  minor_unit: 2,
  today: '2026-09-25',
  employee_statuses: ['pending', 'active', 'exited'],
  salary_revision_reasons: ['merit', 'promotion', 'market_adjustment', 'correction'],
}

export const user: User = { id: 'user-hr', name: 'HR Manager', email: 'hr@example.com' }

export const tokens = (suffix: string): TokenPair => ({
  access_token: `access-${suffix}`,
  expires_in: 900,
  refresh_token: `refresh-${suffix}`,
})

export const countries: Country[] = [
  { id: 'country-in', code: 'IN', name: 'India', employer_cost_multiplier: '1.15' },
  { id: 'country-us', code: 'US', name: 'United States', employer_cost_multiplier: '1.3' },
]

export const departments: Department[] = [
  { id: 'department-eng', name: 'Engineering' },
  { id: 'department-sales', name: 'Sales' },
]

export const levels: Level[] = [
  { id: 'level-3', code: 'L3', name: 'Senior', rank: 3 },
  { id: 'level-4', code: 'L4', name: 'Lead', rank: 4 },
]

export const titles: TitleCount[] = [
  { title: 'Senior Software Engineer', employee_count: 142 },
  { title: 'Senior Sales Engineer', employee_count: 9 },
]

export const ada: Employee = {
  id: 'employee-ada',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  title: 'Senior Software Engineer',
  hire_date: '2021-03-01',
  exit_date: null,
  status: 'active',
  as_of: meta.today,
  country: countries[0],
  department: departments[0],
  level: levels[0],
  current_salary: { amount_cents: 12_000_000, effective_date: '2025-04-01' },
}

export const history: SalaryHistoryEntry[] = [
  {
    id: 'revision-2',
    amount_cents: 12_000_000,
    effective_date: '2025-04-01',
    reason: 'merit',
    note: null,
    voided_at: null,
    previous_amount_cents: 10_000_000,
  },
  {
    id: 'revision-1',
    amount_cents: 10_000_000,
    effective_date: '2021-03-01',
    reason: 'market_adjustment',
    note: 'Starting salary',
    voided_at: null,
    previous_amount_cents: null,
  },
]

export const audits: Audit[] = [
  {
    id: 'audit-2',
    action: 'update',
    auditable_type: 'employee',
    auditable_id: ada.id,
    audited_changes: { title: ['Software Engineer', 'Senior Software Engineer'], level_id: ['level-4', 'level-3'] },
    user,
    created_at: '2026-09-20T10:15:00Z',
  },
  {
    id: 'audit-1',
    action: 'create',
    auditable_type: 'salary_revision',
    auditable_id: 'revision-2',
    audited_changes: { amount_cents: 12_000_000, effective_date: '2025-04-01', reason: 'merit', note: null },
    user: null,
    created_at: '2025-03-20T08:00:00Z',
  },
]

export function page<T>(data: T[], pagination: Partial<Pagination> = {}): { data: T[]; pagination: Pagination } {
  return {
    data,
    pagination: {
      total: data.length,
      page: 1,
      per_page: 25,
      total_pages: data.length > 0 ? 1 : 0,
      prev_page: null,
      next_page: null,
      ...pagination,
    },
  }
}

// The two groups swap places between gross and loaded, so a test can tell the bases apart by order.
export function runRate(groupBy: RunRateGroupBy = 'department'): RunRate {
  const groups = { department: departments, country: countries, level: levels }[groupBy]

  return {
    as_of: meta.today,
    group_by: groupBy,
    data: [
      {
        group: { id: groups[0].id, name: groups[0].name },
        headcount: 3,
        salaried: 2,
        gross_cents: 30_000_000,
        loaded_cents: 30_000_000,
      },
      {
        group: { id: groups[1].id, name: groups[1].name },
        headcount: 1,
        salaried: 1,
        gross_cents: 20_000_000,
        loaded_cents: 30_500_000,
      },
    ],
    totals: { headcount: 4, salaried: 3, gross_cents: 50_000_000, loaded_cents: 60_500_000 },
  }
}

export const trend: TrendPoint[] = [
  {
    date: '2025-09-30',
    headcount: 3,
    salaried: 3,
    gross_cents: 45_000_000,
    loaded_cents: 54_000_000,
    hires: null,
    exits: null,
    raises: null,
    raise_delta_cents: null,
  },
  {
    date: meta.today,
    headcount: 4,
    salaried: 3,
    gross_cents: 50_000_000,
    loaded_cents: 60_500_000,
    hires: 1,
    exits: 0,
    raises: 1,
    raise_delta_cents: 5_000_000,
  },
]

export const distributionRow: DistributionRow = {
  group: { id: levels[0].id, name: levels[0].name },
  headcount: 7,
  min_cents: 8_000_000,
  p25_cents: 9_500_000,
  median_cents: 11_000_000,
  p75_cents: 12_500_000,
  max_cents: 16_000_000,
}

export const cohorts: Cohort[] = [
  {
    level: { id: levels[0].id, name: levels[0].name },
    country: { id: countries[0].id, name: countries[0].name },
    headcount: 7,
    evaluated: true,
    p25_cents: 9_500_000,
    p50_cents: 11_000_000,
    p75_cents: 12_500_000,
    lower_fence_cents: 5_000_000,
    upper_fence_cents: 17_000_000,
    outliers_below: 0,
    outliers_above: 1,
    reason: null,
  },
  {
    level: { id: levels[1].id, name: levels[1].name },
    country: { id: countries[1].id, name: countries[1].name },
    headcount: 3,
    evaluated: false,
    p25_cents: 15_000_000,
    p50_cents: 16_000_000,
    p75_cents: 17_000_000,
    lower_fence_cents: null,
    upper_fence_cents: null,
    outliers_below: null,
    outliers_above: null,
    reason: 'fewer than 5 people',
  },
]

export const outlier: Outlier = {
  id: ada.id,
  name: ada.name,
  department: departments[0],
  level: { id: levels[0].id, name: levels[0].name },
  country: { id: countries[0].id, name: countries[0].name },
  amount_cents: 18_000_000,
  cohort_median_cents: 11_000_000,
  cohort_headcount: 7,
  direction: 'above',
  distance_pct: 63.6,
}
