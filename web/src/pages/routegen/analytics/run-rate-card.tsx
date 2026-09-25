import { Link } from '@tanstack/react-router'
import type { RunRate, RunRateGroupBy } from '@/api/types'
import { Card, CardAction, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Skeleton } from '@/components/ui/skeleton'
import { Spinner } from '@/components/ui/spinner'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useClosedSets, useMeta } from '@/data/app'
import { LOCALE } from '@/lib/locale'
import { formatMoney } from '@/lib/money'
import { GroupToggle } from '@/pages/routegen/analytics/group-toggle'
import { GROUP_LABELS, LOADED_NOTE } from '@/pages/routegen/analytics/labels'
import { type Basis, RUN_RATE_GROUPS } from '@/pages/routegen/analytics/search'

const count = new Intl.NumberFormat(LOCALE)

type RunRateCardProps = {
  runRate: RunRate | undefined
  groupBy: RunRateGroupBy
  basis: Basis
  loading: boolean
  onGroupBy: (groupBy: RunRateGroupBy) => void
}

export function RunRateCard({ runRate, groupBy, basis, loading, onGroupBy }: RunRateCardProps) {
  const meta = useMeta()
  const groups = useGroups(groupBy)
  // The previous grouping stays on screen while the next loads, and its ids match none of these groups.
  const current = runRate?.group_by === groupBy ? runRate : undefined
  const byId = new Map(current?.data.map((row) => [row.group.id, row]))
  const amount = (id: string) => {
    const row = byId.get(id)
    return row ? (basis === 'loaded' ? row.loaded_cents : row.gross_cents) : 0
  }
  // Every group in the closed set, so one with nobody active reads as zero rather than missing.
  const rows = groups
    .map((group) => ({ ...group, row: byId.get(group.id), amount: amount(group.id) }))
    .sort((a, b) => b.amount - a.amount)
  const max = Math.max(...rows.map((row) => row.amount), 1)

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          Run rate by {GROUP_LABELS[groupBy].toLowerCase()}
          {loading && current && <Spinner className="text-muted-foreground" />}
        </CardTitle>
        <CardDescription>
          Annual {basis === 'loaded' ? `fully loaded cost, ${LOADED_NOTE}` : 'gross salary'}. Costliest first.
        </CardDescription>
        <CardAction>
          <GroupToggle groups={RUN_RATE_GROUPS} value={groupBy} onChange={onGroupBy} />
        </CardAction>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent">
              <TableHead>{GROUP_LABELS[groupBy]}</TableHead>
              <TableHead className="w-full">
                <span className="sr-only">Share</span>
              </TableHead>
              <TableHead className="text-right">Headcount</TableHead>
              <TableHead className="text-right">Run rate</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {current
              ? rows.map(({ id, label, hint, row, amount }) => (
                  <TableRow key={id}>
                    <TableCell>
                      <Link
                        to="/employees"
                        search={{ [groupBy]: [id], status: 'active' }}
                        className="font-medium hover:underline"
                      >
                        {label}
                      </Link>
                      {hint && <span className="ml-2 text-xs text-muted-foreground">{hint}</span>}
                    </TableCell>
                    <TableCell>
                      <div className="h-2 min-w-24 rounded-full bg-muted">
                        <div className="h-2 rounded-full bg-chart-1" style={{ width: `${(amount / max) * 100}%` }} />
                      </div>
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {count.format(row?.headcount ?? 0)}
                      {row && row.salaried < row.headcount && (
                        <span className="block text-xs text-muted-foreground">
                          {count.format(row.headcount - row.salaried)} without salary
                        </span>
                      )}
                    </TableCell>
                    <TableCell className="text-right font-medium tabular-nums">{formatMoney(amount, meta)}</TableCell>
                  </TableRow>
                ))
              : Array.from({ length: 5 }, (_, row) => (
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
      </CardContent>
    </Card>
  )
}

function useGroups(groupBy: RunRateGroupBy): { id: string; label: string; hint?: string }[] {
  const { departments, countries, levels } = useClosedSets()

  switch (groupBy) {
    case 'department':
      return departments.map((department) => ({ id: department.id, label: department.name }))
    case 'country':
      return countries.map((country) => ({ id: country.id, label: country.name, hint: country.code }))
    case 'level':
      return levels.map((level) => ({ id: level.id, label: level.code, hint: level.name }))
  }
}
