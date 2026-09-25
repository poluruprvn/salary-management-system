import { api, unwrap } from '@/api/client'
import type { EmployeeInput, EmployeePatch, RevisionInput, RevisionPatch } from '@/api/types'
import { write } from '@/hooks/writes'
import type { EmployeeListSearch } from '@/pages/routegen/employees/search'

export function fetchEmployees(search: EmployeeListSearch, asOf: string, signal: AbortSignal) {
  return unwrap(
    api.GET('/api/v1/employees', {
      params: {
        query: {
          q: search.q,
          'department_id[]': search.department,
          'country_id[]': search.country,
          'level_id[]': search.level,
          status: search.status,
          title: search.title,
          sort: search.sort,
          page: search.page,
          per_page: search.per_page,
          as_of: asOf,
        },
      },
      signal,
    }),
  )
}

export function fetchEmployee(id: string, asOf: string, signal: AbortSignal) {
  return unwrap(api.GET('/api/v1/employees/{id}', { params: { path: { id }, query: { as_of: asOf } }, signal }))
}

export async function fetchSalaryHistory(employeeId: string, signal: AbortSignal) {
  const { data } = await unwrap(
    api.GET('/api/v1/employees/{employee_id}/salary_revisions', { params: { path: { employee_id: employeeId } }, signal }),
  )
  return data
}

export function fetchAudits(employeeId: string, page: number, signal: AbortSignal) {
  return unwrap(
    api.GET('/api/v1/employees/{employee_id}/audits', {
      params: { path: { employee_id: employeeId }, query: { page } },
      signal,
    }),
  )
}

export async function fetchTitles(q: string, signal: AbortSignal) {
  const { data } = await unwrap(api.GET('/api/v1/titles', { params: { query: { q } }, signal }))
  return data
}

export function createEmployee(input: EmployeeInput) {
  return write(() => unwrap(api.POST('/api/v1/employees', { body: input })))
}

export function updateEmployee(id: string, patch: EmployeePatch) {
  return write(() => unwrap(api.PATCH('/api/v1/employees/{id}', { params: { path: { id } }, body: patch })))
}

export function addRevision(employeeId: string, input: RevisionInput) {
  return write(() =>
    unwrap(
      api.POST('/api/v1/employees/{employee_id}/salary_revisions', {
        params: { path: { employee_id: employeeId } },
        body: input,
      }),
    ),
  )
}

export function correctRevision(employeeId: string, id: string, patch: RevisionPatch) {
  return write(() =>
    unwrap(
      api.PATCH('/api/v1/employees/{employee_id}/salary_revisions/{id}', {
        params: { path: { employee_id: employeeId, id } },
        body: patch,
      }),
    ),
  )
}

export function voidRevision(employeeId: string, id: string) {
  return write(() =>
    unwrap(
      api.DELETE('/api/v1/employees/{employee_id}/salary_revisions/{id}', {
        params: { path: { employee_id: employeeId, id } },
      }),
    ),
  )
}
