import type { components, paths } from '@/api/schema'

type Schemas = components['schemas']

export type TokenPair = Schemas['token_pair']
export type ErrorBody = Schemas['error']
export type Pagination = Schemas['pagination']
export type User = Schemas['user']
export type Meta = Schemas['meta']
export type Country = Schemas['country']
export type Department = Schemas['department']
export type Level = Schemas['level']
export type Employee = Schemas['employee']
export type EmployeeStatus = Employee['status']
type SalaryRevision = Schemas['salary_revision']
export type SalaryHistoryEntry = Schemas['salary_history_entry']
export type SalaryChange = Schemas['salary_change']
export type SalaryReason = SalaryRevision['reason']
export type Audit = Schemas['audit']
export type TitleCount = Schemas['title_count']

export type EmployeeSort = NonNullable<NonNullable<paths['/api/v1/employees']['get']['parameters']['query']>['sort']>
export type EmployeeInput = paths['/api/v1/employees']['post']['requestBody']['content']['application/json']
export type EmployeePatch = paths['/api/v1/employees/{id}']['patch']['requestBody']['content']['application/json']
export type RevisionInput =
  paths['/api/v1/employees/{employee_id}/salary_revisions']['post']['requestBody']['content']['application/json']
export type RevisionPatch =
  paths['/api/v1/employees/{employee_id}/salary_revisions/{id}']['patch']['requestBody']['content']['application/json']
