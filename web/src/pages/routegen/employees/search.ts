import { z } from 'zod'
import type { EmployeeSort, EmployeeStatus } from '@/api/types'

export const SORT_KEYS = ['name', 'hire_date', 'exit_date', 'salary', 'department', 'country', 'level'] as const

const SORTS = SORT_KEYS.flatMap((key) => [key, `-${key}`] as const) satisfies EmployeeSort[]

export const STATUSES = ['active', 'pending', 'exited'] as const satisfies readonly EmployeeStatus[]

export const PER_PAGE = [25, 50, 100] as const

export const FILTER_KEYS = ['q', 'department', 'country', 'level', 'status', 'title'] as const

const ids = z.array(z.string()).optional().catch(undefined)

// A param that does not parse falls back to its default. A mangled link still opens a list.
export const employeeListSearch = z.object({
  q: z.string().optional().catch(undefined),
  department: ids,
  country: ids,
  level: ids,
  status: z.enum(STATUSES).optional().catch(undefined),
  title: z.string().optional().catch(undefined),
  sort: z.enum(SORTS).default('name').catch('name'),
  page: z.int().min(1).default(1).catch(1),
  per_page: z.literal(PER_PAGE).default(25).catch(25),
})

export type EmployeeListSearch = z.output<typeof employeeListSearch>

export const EMPLOYEE_LIST_DEFAULTS = employeeListSearch.parse({})

export const employeeSearch = z.object({
  tab: z.enum(['history', 'changes']).default('history').catch('history'),
  changes_page: z.int().min(1).default(1).catch(1),
})

export const EMPLOYEE_DEFAULTS = employeeSearch.parse({})
