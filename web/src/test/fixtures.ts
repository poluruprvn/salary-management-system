import type {
  Audit,
  Country,
  Department,
  Employee,
  Level,
  Meta,
  Pagination,
  SalaryHistoryEntry,
  TitleCount,
  TokenPair,
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
  { id: 'country-in', code: 'IN', name: 'India' },
  { id: 'country-us', code: 'US', name: 'United States' },
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
