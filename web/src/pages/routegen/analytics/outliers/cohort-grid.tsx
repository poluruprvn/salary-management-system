import type { Cohort } from '@/api/types'
import { ErrorPanel } from '@/components/error-panel'
import { Skeleton } from '@/components/ui/skeleton'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip'
import { useAsOf, useClosedSets, useMeta } from '@/data/app'
import { useApi } from '@/hooks/use-api'
import { LOCALE } from '@/lib/locale'
import { formatMoney } from '@/lib/money'
import { cn } from '@/lib/utils'
import { fetchCohorts } from '@/pages/routegen/analytics/data'

const count = new Intl.NumberFormat(LOCALE)

export function CohortGrid({ onOpen }: { onOpen: (levelId: string, countryId: string) => void }) {
  const { asOf } = useAsOf()
  const { levels, countries } = useClosedSets()
  const result = useApi(['cohorts', asOf], (signal) => fetchCohorts(asOf, signal))

  if (result.error) {
    return <ErrorPanel title="Could not load cohorts" error={result.error} onRetry={result.retry} />
  }
  if (!result.data) return <Skeleton className="h-96 w-full" />

  const cohorts = new Map(result.data.map((cohort) => [`${cohort.level.id}:${cohort.country.id}`, cohort]))

  return (
    <div className="flex flex-col gap-3">
      <p className="text-sm text-muted-foreground">
        People with a salary in force, and how many sit outside the fence. A cohort needs 5 people to be evaluated.
      </p>
      <div className="overflow-x-auto rounded-lg border">
        <Table className="min-w-3xl table-fixed">
          <TableHeader>
            <TableRow className="hover:bg-transparent">
              <TableHead className="w-40">Level</TableHead>
              {countries.map((country) => (
                <TableHead key={country.id} className="text-center">
                  <abbr title={country.name} className="no-underline">
                    {country.code}
                  </abbr>
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {levels.map((level) => (
              <TableRow key={level.id} className="hover:bg-transparent">
                <TableCell className="whitespace-nowrap">
                  <span className="font-mono text-xs">{level.code}</span>{' '}
                  <span className="text-muted-foreground">{level.name}</span>
                </TableCell>
                {countries.map((country) => (
                  <TableCell key={country.id} className="p-1 text-center">
                    <CohortCell
                      cohort={cohorts.get(`${level.id}:${country.id}`)}
                      onOpen={() => onOpen(level.id, country.id)}
                    />
                  </TableCell>
                ))}
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </div>
    </div>
  )
}

function CohortCell({ cohort, onOpen }: { cohort: Cohort | undefined; onOpen: () => void }) {
  const meta = useMeta()

  if (!cohort) return <span className="text-muted-foreground">—</span>

  if (!cohort.evaluated) {
    return (
      <div className="flex flex-col rounded-md px-2 py-1.5 text-xs whitespace-normal text-muted-foreground">
        <span className="text-sm tabular-nums">{count.format(cohort.headcount)}</span>
        <span>Not evaluated, {cohort.reason}</span>
      </div>
    )
  }

  const outliers = (cohort.outliers_below ?? 0) + (cohort.outliers_above ?? 0)
  const money = (cents: number | null) => (cents === null ? '—' : formatMoney(cents, meta))

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <button
          type="button"
          onClick={onOpen}
          className={cn(
            'flex w-full flex-col items-center rounded-md px-2 py-1.5 text-xs whitespace-normal transition-colors hover:bg-muted',
            outliers > 0 && 'bg-chart-2/15',
          )}
        >
          <span className="text-sm tabular-nums">{count.format(cohort.headcount)}</span>
          <span className={cn('tabular-nums', outliers === 0 && 'text-muted-foreground')}>
            {outliers === 0 ? 'none outside' : `${count.format(outliers)} outside`}
          </span>
        </button>
      </TooltipTrigger>
      <TooltipContent>
        <div className="tabular-nums">
          {cohort.level.name}, {cohort.country.name}. Median {formatMoney(cohort.p50_cents, meta)}.
          <br />
          {cohort.outliers_below ?? '—'} below, {cohort.outliers_above ?? '—'} above.
          <br />
          Fence {money(cohort.lower_fence_cents)} to {money(cohort.upper_fence_cents)}.
        </div>
      </TooltipContent>
    </Tooltip>
  )
}
