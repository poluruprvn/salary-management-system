import { getRouteApi } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import type { RunRate } from '@/api/types'
import { ErrorPanel } from '@/components/error-panel'
import { Card, CardContent } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { useAsOf, useMeta } from '@/data/app'
import { useApi } from '@/hooks/use-api'
import { formatDate } from '@/lib/dates'
import { LOCALE } from '@/lib/locale'
import { formatMoney } from '@/lib/money'
import { AnalyticsHeader } from '@/pages/routegen/analytics/analytics-header'
import { BasisToggle } from '@/pages/routegen/analytics/basis-toggle'
import { fetchRunRate, fetchTrend } from '@/pages/routegen/analytics/data'
import { LOADED_NOTE } from '@/pages/routegen/analytics/labels'
import { RunRateCard } from '@/pages/routegen/analytics/run-rate-card'
import type { Basis } from '@/pages/routegen/analytics/search'
import { TrendCard } from '@/pages/routegen/analytics/trend-card'

const route = getRouteApi('/app/analytics')

const count = new Intl.NumberFormat(LOCALE)

export function AnalyticsPage() {
  const { basis, group_by } = route.useSearch()
  const navigate = route.useNavigate()
  const { asOf } = useAsOf()
  // basis is not in either key: both figures come back together, so the toggle needs no request.
  const runRate = useApi(['run_rate', group_by, asOf], (signal) => fetchRunRate(group_by, asOf, signal))
  const trend = useApi(['trend', asOf], (signal) => fetchTrend(asOf, signal))

  return (
    <div className="flex flex-col gap-6">
      <AnalyticsHeader description={`Active employees and annual pay as of ${formatDate(asOf)}`}>
        <BasisToggle
          value={basis}
          onChange={(next) => void navigate({ search: (prev) => ({ ...prev, basis: next }), replace: true })}
        />
      </AnalyticsHeader>

      {runRate.error ? (
        <ErrorPanel title="Could not load the run rate" error={runRate.error} onRetry={runRate.retry} />
      ) : (
        <Stats runRate={runRate.data} basis={basis} />
      )}

      {trend.error ? (
        <ErrorPanel title="Could not load the last twelve months" error={trend.error} onRetry={trend.retry} />
      ) : (
        <TrendCard points={trend.data} basis={basis} />
      )}

      {!runRate.error && (
        <RunRateCard
          runRate={runRate.data}
          groupBy={group_by}
          basis={basis}
          loading={runRate.loading}
          onGroupBy={(next) => void navigate({ search: (prev) => ({ ...prev, group_by: next }), replace: true })}
        />
      )}
    </div>
  )
}

function Stats({ runRate, basis }: { runRate: RunRate | undefined; basis: Basis }) {
  const meta = useMeta()
  const totals = runRate?.totals
  const unsalaried = totals ? totals.headcount - totals.salaried : 0

  return (
    <div className="grid gap-4 sm:grid-cols-3">
      <Stat label="Active headcount">{totals && count.format(totals.headcount)}</Stat>
      <Stat
        label={basis === 'loaded' ? 'Annual run rate, fully loaded' : 'Annual run rate, gross'}
        note={basis === 'loaded' ? LOADED_NOTE : 'salary only'}
      >
        {totals && formatMoney(basis === 'loaded' ? totals.loaded_cents : totals.gross_cents, meta)}
      </Stat>
      {unsalaried > 0 && (
        <Stat label="No salary on file" note="not in the run rate">
          {`${count.format(unsalaried)} active ${unsalaried === 1 ? 'employee' : 'employees'}`}
        </Stat>
      )}
    </div>
  )
}

function Stat({ label, note, children }: { label: string; note?: string; children: ReactNode }) {
  return (
    <Card size="sm">
      <CardContent className="flex flex-col gap-1">
        <span className="text-xs text-muted-foreground">{label}</span>
        {children ? (
          <span className="text-2xl font-semibold tracking-tight tabular-nums">{children}</span>
        ) : (
          <Skeleton className="h-8 w-32" />
        )}
        {note && <span className="text-xs text-muted-foreground">{note}</span>}
      </CardContent>
    </Card>
  )
}
