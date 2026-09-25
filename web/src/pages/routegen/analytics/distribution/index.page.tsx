import { getRouteApi, Link } from '@tanstack/react-router'
import { SearchXIcon } from 'lucide-react'
import type { DistributionGroupBy, DistributionRow } from '@/api/types'
import { ErrorPanel } from '@/components/error-panel'
import { FacetedFilter } from '@/components/faceted-filter'
import { PageNav } from '@/components/page-nav'
import { PastEnd } from '@/components/past-end'
import { SortableHead } from '@/components/sortable-head'
import { Button } from '@/components/ui/button'
import { Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle } from '@/components/ui/empty'
import { Skeleton } from '@/components/ui/skeleton'
import { Spinner } from '@/components/ui/spinner'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useAsOf, useClosedSets, useMeta } from '@/data/app'
import { useApi } from '@/hooks/use-api'
import { formatDate } from '@/lib/dates'
import { LOCALE } from '@/lib/locale'
import { formatMoney } from '@/lib/money'
import { AnalyticsHeader } from '@/pages/routegen/analytics/analytics-header'
import { fetchDistribution } from '@/pages/routegen/analytics/data'
import { GroupToggle } from '@/pages/routegen/analytics/group-toggle'
import { GROUP_LABELS } from '@/pages/routegen/analytics/labels'
import { RangeStrip, type Scale } from '@/pages/routegen/analytics/range-strip'
import {
  defaultDistributionSort,
  DISTRIBUTION_GROUPS,
  type DistributionSearch,
} from '@/pages/routegen/analytics/search'
import { TitleFilter } from '@/pages/routegen/employees/title-filter'

const route = getRouteApi('/app/analytics/distribution')

const count = new Intl.NumberFormat(LOCALE)

const FILTER_KEYS = ['department', 'country', 'level', 'title'] as const

const NO_FILTERS = Object.fromEntries(FILTER_KEYS.map((key) => [key, undefined]))

type Update = (changes: Partial<DistributionSearch>) => void

export function DistributionPage() {
  const { as_of: _, ...search } = route.useSearch()
  const navigate = route.useNavigate()
  const { asOf } = useAsOf()
  const result = useApi(['distribution', search, asOf], (signal) => fetchDistribution(search, asOf, signal))
  const distribution = result.data
  const pagination = distribution?.pagination
  const filtered = FILTER_KEYS.some((key) => search[key] !== undefined)

  const update: Update = (changes) => void navigate({ search: (prev) => ({ ...prev, page: undefined, ...changes }) })

  return (
    <div className="flex flex-col gap-4">
      <AnalyticsHeader description={`Gross annual salary of active employees as of ${formatDate(asOf)}`} />

      <div className="flex flex-wrap items-center gap-2">
        <GroupToggle
          groups={DISTRIBUTION_GROUPS}
          value={search.group_by}
          onChange={(group_by) => update({ group_by, sort: undefined })}
        />
        <Filters search={search} filtered={filtered} update={update} />
        {result.loading && distribution && <Spinner className="text-muted-foreground" />}
      </div>

      {result.error ? (
        <ErrorPanel title="Could not load the distribution" error={result.error} onRetry={result.retry} />
      ) : pagination?.total === 0 ? (
        <Empty className="border">
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <SearchXIcon />
            </EmptyMedia>
            <EmptyTitle>Nobody matches</EmptyTitle>
            <EmptyDescription>
              {filtered ? 'No active employee with a salary matches these filters.' : 'No active employee has a salary.'}
            </EmptyDescription>
          </EmptyHeader>
        </Empty>
      ) : pagination && pagination.page > pagination.total_pages ? (
        <PastEnd pagination={pagination} onPage={(page) => update({ page })} />
      ) : (
        <div className="overflow-hidden rounded-lg border">
          <DistributionTable
            rows={distribution?.group_by === search.group_by ? distribution.data : undefined}
            search={search}
            onSort={(sort) => update({ sort })}
          />
        </div>
      )}

      {distribution && (
        <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-muted-foreground">
          <p>
            Percentiles are interpolated. Each group counts people with a salary in force.
            {distribution.unsalaried > 0 &&
              ` ${count.format(distribution.unsalaried)} active ${distribution.unsalaried === 1 ? 'employee' : 'employees'} matched but have no salary on file, so they are left out.`}
          </p>
          {pagination && <PageNav pagination={pagination} onPage={(page) => update({ page })} />}
        </div>
      )}
    </div>
  )
}

function Filters({ search, filtered, update }: { search: DistributionSearch; filtered: boolean; update: Update }) {
  const { departments, countries, levels } = useClosedSets()
  const ids = (values: string[]) => (values.length > 0 ? values : undefined)

  return (
    <>
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
      {filtered && (
        <Button variant="ghost" size="sm" onClick={() => update(NO_FILTERS)}>
          Reset
        </Button>
      )}
    </>
  )
}

type DistributionTableProps = {
  rows: DistributionRow[] | undefined
  search: DistributionSearch
  onSort: (sort: DistributionSearch['sort']) => void
}

function DistributionTable({ rows, search, onSort }: DistributionTableProps) {
  const meta = useMeta()
  const sorting = { sort: search.sort ?? defaultDistributionSort(search.group_by), onSort }
  const scale: Scale | undefined = rows && {
    min: Math.min(...rows.map((row) => row.min_cents)),
    max: Math.max(...rows.map((row) => row.max_cents)),
  }

  return (
    <Table>
      <TableHeader>
        <TableRow className="hover:bg-transparent">
          <SortableHead sortKey="name" {...sorting}>
            {GROUP_LABELS[search.group_by]}
          </SortableHead>
          <SortableHead sortKey="headcount" align="right" {...sorting}>
            People
          </SortableHead>
          <TableHead className="w-full">
            <span className="sr-only">Range</span>
            {scale && (
              <span aria-hidden className="flex justify-between text-xs font-normal text-muted-foreground tabular-nums">
                <span>{formatMoney(scale.min, meta)}</span>
                <span>{formatMoney(scale.max, meta)}</span>
              </span>
            )}
          </TableHead>
          <SortableHead sortKey="median" align="right" {...sorting}>
            Median
          </SortableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {rows && scale
          ? rows.map((row) => (
              <TableRow key={row.group.id}>
                <TableCell className="max-w-64">
                  <GroupLink groupBy={search.group_by} row={row} search={search} />
                </TableCell>
                <TableCell className="text-right tabular-nums">{count.format(row.headcount)}</TableCell>
                <TableCell>
                  <RangeStrip
                    min={row.min_cents}
                    p25={row.p25_cents}
                    median={row.median_cents}
                    p75={row.p75_cents}
                    max={row.max_cents}
                    scale={scale}
                  />
                </TableCell>
                <TableCell className="text-right font-medium tabular-nums">
                  {formatMoney(row.median_cents, meta)}
                </TableCell>
              </TableRow>
            ))
          : Array.from({ length: 8 }, (_, row) => (
              <TableRow key={row}>
                {Array.from({ length: 4 }, (_, cell) => (
                  <TableCell key={cell}>
                    <Skeleton className="h-4 w-full max-w-28" />
                  </TableCell>
                ))}
              </TableRow>
            ))}
      </TableBody>
    </Table>
  )
}

// The employee list for this group: the filters here, the group, and active. It also lists people with no salary.
function GroupLink({ groupBy, row, search }: { groupBy: DistributionGroupBy; row: DistributionRow; search: DistributionSearch }) {
  const { levels } = useClosedSets()
  const level = groupBy === 'level' ? levels.find((candidate) => candidate.id === row.group.id) : undefined
  const filters = {
    department: search.department,
    country: search.country,
    level: search.level,
    title: search.title,
    status: 'active' as const,
    ...(groupBy === 'title' ? { title: row.group.id } : { [groupBy]: [row.group.id] }),
  }

  return (
    <Link to="/employees" search={filters} className="block truncate font-medium hover:underline">
      {level ? (
        <>
          {level.code} <span className="font-normal text-muted-foreground">· {level.name}</span>
        </>
      ) : (
        row.group.name
      )}
    </Link>
  )
}
