import { Link } from '@tanstack/react-router'
import { SearchCheckIcon } from 'lucide-react'
import type { Outlier } from '@/api/types'
import { ErrorPanel } from '@/components/error-panel'
import { FacetedFilter } from '@/components/faceted-filter'
import { PageNav } from '@/components/page-nav'
import { PastEnd } from '@/components/past-end'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle } from '@/components/ui/empty'
import { Skeleton } from '@/components/ui/skeleton'
import { Spinner } from '@/components/ui/spinner'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { useAsOf, useClosedSets, useMeta } from '@/data/app'
import { useApi } from '@/hooks/use-api'
import { LOCALE } from '@/lib/locale'
import { formatMoney, formatPercent } from '@/lib/money'
import { fetchOutliers } from '@/pages/routegen/analytics/data'
import { DIRECTIONS, type OutliersSearch } from '@/pages/routegen/analytics/search'

const count = new Intl.NumberFormat(LOCALE)

const DIRECTION_LABELS = { below: 'Below', above: 'Above' } as const

const COLUMN_COUNT = 7

type Update = (changes: Partial<OutliersSearch>) => void

export function OutlierList({ search, update }: { search: OutliersSearch; update: Update }) {
  const { asOf } = useAsOf()
  const { tab: _, ...query } = search
  const result = useApi(['outliers', query, asOf], (signal) => fetchOutliers(search, asOf, signal))
  const pagination = result.data?.pagination
  const filtered = !!(search.department || search.country || search.level || search.direction)

  return (
    <div className="flex flex-col gap-4">
      <Filters search={search} filtered={filtered} update={update} loading={result.loading && !!result.data} />
      <p className="text-sm text-muted-foreground">
        Filters narrow who is listed. The fence is always drawn from everyone at the same level in the same country.
      </p>

      {result.error ? (
        <ErrorPanel title="Could not load outliers" error={result.error} onRetry={result.retry} />
      ) : pagination?.total === 0 ? (
        <Empty className="border">
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <SearchCheckIcon />
            </EmptyMedia>
            <EmptyTitle>No outliers</EmptyTitle>
            <EmptyDescription>
              {filtered ? 'Nobody matching these filters is outside their fence.' : 'Everyone is inside their fence.'}
            </EmptyDescription>
          </EmptyHeader>
        </Empty>
      ) : pagination && pagination.page > pagination.total_pages ? (
        <PastEnd pagination={pagination} onPage={(page) => update({ page })} />
      ) : (
        <div className="overflow-hidden rounded-lg border">
          <OutlierTable outliers={result.data?.data} />
        </div>
      )}

      {pagination && pagination.total > 0 && pagination.page <= pagination.total_pages && (
        <div className="flex flex-wrap items-center justify-between gap-3 text-sm text-muted-foreground">
          <span className="tabular-nums">
            {count.format(pagination.total)} {pagination.total === 1 ? 'person' : 'people'}, farthest from the median first
          </span>
          <PageNav pagination={pagination} onPage={(page) => update({ page })} />
        </div>
      )}
    </div>
  )
}

type FiltersProps = { search: OutliersSearch; filtered: boolean; loading: boolean; update: Update }

function Filters({ search, filtered, loading, update }: FiltersProps) {
  const { departments, countries, levels } = useClosedSets()
  const ids = (values: string[]) => (values.length > 0 ? values : undefined)

  return (
    <div className="flex flex-wrap items-center gap-2">
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
      <ToggleGroup
        type="single"
        variant="outline"
        size="sm"
        spacing={0}
        value={search.direction ?? 'both'}
        onValueChange={(value) => {
          if (value) update({ direction: value === 'both' ? undefined : (value as OutliersSearch['direction']) })
        }}
        aria-label="Direction"
      >
        <ToggleGroupItem value="both">Both</ToggleGroupItem>
        {DIRECTIONS.map((direction) => (
          <ToggleGroupItem key={direction} value={direction}>
            {DIRECTION_LABELS[direction]}
          </ToggleGroupItem>
        ))}
      </ToggleGroup>
      {filtered && (
        <Button
          variant="ghost"
          size="sm"
          onClick={() => update({ department: undefined, country: undefined, level: undefined, direction: undefined })}
        >
          Reset
        </Button>
      )}
      {loading && <Spinner className="text-muted-foreground" />}
    </div>
  )
}

function OutlierTable({ outliers }: { outliers: Outlier[] | undefined }) {
  const meta = useMeta()
  const { levels } = useClosedSets()
  const levelCode = (id: string, name: string) => levels.find((level) => level.id === id)?.code ?? name

  return (
    <Table>
      <TableHeader>
        <TableRow className="hover:bg-transparent">
          <TableHead>Name</TableHead>
          <TableHead>Level</TableHead>
          <TableHead>Country</TableHead>
          <TableHead>Department</TableHead>
          <TableHead className="text-right">Salary</TableHead>
          <TableHead className="text-right">Cohort median</TableHead>
          <TableHead className="text-right">From median</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {outliers
          ? outliers.map((outlier) => (
              <TableRow key={outlier.id}>
                <TableCell className="max-w-64">
                  <Link
                    to="/employees/$employeeId"
                    params={{ employeeId: outlier.id }}
                    className="block truncate font-medium hover:underline"
                  >
                    {outlier.name}
                  </Link>
                </TableCell>
                <TableCell className="font-mono text-xs">{levelCode(outlier.level.id, outlier.level.name)}</TableCell>
                <TableCell>{outlier.country.name}</TableCell>
                <TableCell>{outlier.department.name}</TableCell>
                <TableCell className="text-right font-medium tabular-nums">
                  {formatMoney(outlier.amount_cents, meta)}
                </TableCell>
                <TableCell className="text-right tabular-nums">
                  {formatMoney(outlier.cohort_median_cents, meta)}
                  <span className="block text-xs text-muted-foreground">
                    of {count.format(outlier.cohort_headcount)} people
                  </span>
                </TableCell>
                <TableCell className="text-right">
                  <Badge variant={outlier.direction === 'above' ? 'secondary' : 'outline'} className="tabular-nums">
                    {formatPercent(outlier.distance_pct)}
                  </Badge>
                </TableCell>
              </TableRow>
            ))
          : Array.from({ length: 10 }, (_, row) => (
              <TableRow key={row}>
                {Array.from({ length: COLUMN_COUNT }, (_, cell) => (
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
