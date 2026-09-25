import { getRouteApi, Link } from '@tanstack/react-router'
import { PlusIcon, SearchXIcon } from 'lucide-react'
import { useEffect } from 'react'
import type { Employee, Pagination } from '@/api/types'
import { ErrorPanel } from '@/components/error-panel'
import { FacetedFilter } from '@/components/faceted-filter'
import { PageNav } from '@/components/page-nav'
import { PastEnd } from '@/components/past-end'
import { SearchInput } from '@/components/search-input'
import { Button } from '@/components/ui/button'
import { Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle } from '@/components/ui/empty'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Spinner } from '@/components/ui/spinner'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { useAsOf, useClosedSets } from '@/data/app'
import { useApi } from '@/hooks/use-api'
import { formatDate } from '@/lib/dates'
import { LOCALE } from '@/lib/locale'
import { fetchEmployees } from '@/pages/routegen/employees/data'
import { EmployeeTable } from '@/pages/routegen/employees/employee-table'
import { STATUS_LABELS } from '@/pages/routegen/employees/labels'
import { rememberListSearch } from '@/pages/routegen/employees/list-store'
import { type EmployeeListSearch, FILTER_KEYS, PER_PAGE, STATUSES } from '@/pages/routegen/employees/search'
import { TitleFilter } from '@/pages/routegen/employees/title-filter'

const route = getRouteApi('/app/employees')

const count = new Intl.NumberFormat(LOCALE)

const NO_FILTERS = Object.fromEntries(FILTER_KEYS.map((key) => [key, undefined]))

type Update = (changes: Partial<EmployeeListSearch>, options?: { replace?: boolean }) => void

export function EmployeesPage() {
  // as_of belongs to the layout. The back link keeps its own, so the remembered search leaves it out.
  const { as_of: _, ...search } = route.useSearch()
  const navigate = route.useNavigate()
  const { asOf } = useAsOf()
  const result = useApi(['employees', search, asOf], (signal) => fetchEmployees(search, asOf, signal))
  const pagination = result.data?.pagination
  const filtered = FILTER_KEYS.some((key) => search[key] !== undefined)

  useEffect(() => rememberListSearch(search))

  // Any change but paging starts again from page 1.
  const update: Update = (changes, { replace } = {}) => {
    void navigate({ search: (prev) => ({ ...prev, page: undefined, ...changes }), replace })
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="font-heading text-xl font-semibold tracking-tight">Employees</h1>
          <p className="text-sm text-muted-foreground">
            {pagination && `${peopleCount(pagination.total)} · `}status and salary as of {formatDate(asOf)}
          </p>
        </div>
        <Button asChild>
          <Link to="/employees/new">
            <PlusIcon />
            New employee
          </Link>
        </Button>
      </div>

      <Filters search={search} filtered={filtered} loading={result.loading && !!result.data} update={update} />

      {result.error ? (
        <ErrorPanel title="Could not load employees" error={result.error} onRetry={result.retry} />
      ) : (
        <Results
          employees={result.data?.data}
          pagination={pagination}
          search={search}
          filtered={filtered}
          update={update}
        />
      )}

      {pagination && pagination.total > 0 && (
        <div className="flex flex-wrap items-center justify-between gap-3 text-sm">
          <div className="flex items-center gap-3 text-muted-foreground">
            <span className="tabular-nums">{rangeLabel(pagination)}</span>
            <Select
              value={String(search.per_page)}
              onValueChange={(value) => update({ per_page: Number(value) as EmployeeListSearch['per_page'] })}
            >
              <SelectTrigger size="sm" aria-label="Rows per page">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {PER_PAGE.map((size) => (
                  <SelectItem key={size} value={String(size)}>
                    {size} per page
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <PageNav pagination={pagination} onPage={(page) => update({ page })} />
        </div>
      )}
    </div>
  )
}

type FiltersProps = { search: EmployeeListSearch; filtered: boolean; loading: boolean; update: Update }

function Filters({ search, filtered, loading, update }: FiltersProps) {
  const { departments, countries, levels } = useClosedSets()
  const ids = (values: string[]) => (values.length > 0 ? values : undefined)

  return (
    <div className="flex flex-wrap items-center gap-2">
      <SearchInput
        value={search.q ?? ''}
        onSearch={(q) => update({ q: q.trim() || undefined }, { replace: true })}
        placeholder="Search name, email or title"
      />
      <FacetedFilter
        title="Department"
        options={departments.map((department) => ({ value: department.id, label: department.name }))}
        selected={search.department ?? []}
        onChange={(values) => update({ department: ids(values) })}
      />
      <FacetedFilter
        title="Country"
        options={countries.map((country) => ({ value: country.id, label: country.name, hint: country.code }))}
        selected={search.country ?? []}
        onChange={(values) => update({ country: ids(values) })}
      />
      <FacetedFilter
        title="Level"
        options={levels.map((level) => ({ value: level.id, label: level.code, hint: level.name }))}
        selected={search.level ?? []}
        onChange={(values) => update({ level: ids(values) })}
      />
      <TitleFilter value={search.title} onChange={(title) => update({ title })} />
      <ToggleGroup
        type="single"
        variant="outline"
        size="sm"
        spacing={0}
        value={search.status ?? 'all'}
        onValueChange={(value) => {
          if (value) update({ status: value === 'all' ? undefined : (value as EmployeeListSearch['status']) })
        }}
        aria-label="Status"
      >
        <ToggleGroupItem value="all">All</ToggleGroupItem>
        {STATUSES.map((status) => (
          <ToggleGroupItem key={status} value={status}>
            {STATUS_LABELS[status]}
          </ToggleGroupItem>
        ))}
      </ToggleGroup>
      {filtered && (
        <Button variant="ghost" size="sm" onClick={() => update(NO_FILTERS)}>
          Reset
        </Button>
      )}
      {loading && <Spinner className="text-muted-foreground" />}
    </div>
  )
}

type ResultsProps = {
  employees: Employee[] | undefined
  pagination: Pagination | undefined
  search: EmployeeListSearch
  filtered: boolean
  update: Update
}

function Results({ employees, pagination, search, filtered, update }: ResultsProps) {
  if (pagination?.total === 0) {
    return (
      <Empty className="border">
        <EmptyHeader>
          <EmptyMedia variant="icon">
            <SearchXIcon />
          </EmptyMedia>
          <EmptyTitle>No employees match</EmptyTitle>
          <EmptyDescription>
            {filtered ? 'Try fewer filters, or another search.' : 'Nobody is on file yet.'}
          </EmptyDescription>
        </EmptyHeader>
      </Empty>
    )
  }

  if (pagination && pagination.page > pagination.total_pages) return <PastEnd pagination={pagination} onPage={(page) => update({ page })} />

  return (
    <div className="overflow-hidden rounded-lg border">
      <EmployeeTable
        employees={employees}
        perPage={search.per_page}
        sort={search.sort}
        onSort={(sort) => update({ sort })}
      />
    </div>
  )
}

function peopleCount(total: number): string {
  return `${count.format(total)} ${total === 1 ? 'person' : 'people'}`
}

function rangeLabel({ page, per_page, total, total_pages }: Pagination): string {
  if (page > total_pages) return peopleCount(total)

  const first = (page - 1) * per_page + 1
  const last = Math.min(page * per_page, total)
  return `${count.format(first)}–${count.format(last)} of ${count.format(total)}`
}
