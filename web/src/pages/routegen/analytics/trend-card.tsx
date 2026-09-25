import { CartesianGrid, Line, LineChart, XAxis, YAxis } from 'recharts'
import type { TrendPoint } from '@/api/types'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { type ChartConfig, ChartContainer, ChartTooltip, ChartTooltipContent } from '@/components/ui/chart'
import { Skeleton } from '@/components/ui/skeleton'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useMeta } from '@/data/app'
import { formatDate } from '@/lib/dates'
import { LOCALE } from '@/lib/locale'
import { formatCompactMoney, formatMoney } from '@/lib/money'
import { LOADED_NOTE } from '@/pages/routegen/analytics/labels'
import type { Basis } from '@/pages/routegen/analytics/search'

const count = new Intl.NumberFormat(LOCALE)
const monthFormat = new Intl.DateTimeFormat(LOCALE, { month: 'short', year: '2-digit', timeZone: 'UTC' })

const chartConfig = { amount: { label: 'Run rate', color: 'var(--chart-1)' } } satisfies ChartConfig

export function TrendCard({ points, basis }: { points: TrendPoint[] | undefined; basis: Basis }) {
  const meta = useMeta()
  const amount = (point: TrendPoint) => (basis === 'loaded' ? point.loaded_cents : point.gross_cents)
  const chartData = points?.map((point) => ({ date: point.date, amount: amount(point) }))

  return (
    <Card>
      <CardHeader>
        <CardTitle>Twelve months</CardTitle>
        <CardDescription>
          Annual {basis === 'loaded' ? `fully loaded run rate, ${LOADED_NOTE}` : 'gross run rate'}, at each month end
          and on the date in use. Hires, exits and raises count the days since the date before.
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-6">
        {chartData ? (
          <ChartContainer config={chartConfig} className="aspect-auto h-64 w-full">
            <LineChart data={chartData} margin={{ left: 8, right: 16, top: 8 }} accessibilityLayer>
              <CartesianGrid vertical={false} />
              <XAxis
                dataKey="date"
                tickLine={false}
                axisLine={false}
                tickMargin={8}
                tickFormatter={(date: string) => monthFormat.format(new Date(`${date}T00:00:00Z`))}
              />
              <YAxis
                tickLine={false}
                axisLine={false}
                width={64}
                domain={['auto', 'auto']}
                tickFormatter={(cents: number) => formatCompactMoney(cents, meta)}
              />
              <ChartTooltip
                content={
                  <ChartTooltipContent
                    labelFormatter={(_, payload) => formatDate(String(payload[0]?.payload?.date))}
                    formatter={(value) => (
                      <span className="font-medium tabular-nums">{formatMoney(Number(value), meta)}</span>
                    )}
                  />
                }
              />
              <Line
                dataKey="amount"
                type="linear"
                stroke="var(--color-amount)"
                strokeWidth={2}
                dot={{ r: 3, fill: 'var(--color-amount)' }}
                activeDot={{ r: 5 }}
                isAnimationActive={false}
              />
            </LineChart>
          </ChartContainer>
        ) : (
          <Skeleton className="h-64 w-full" />
        )}
        {points && <MovementTable points={points} />}
      </CardContent>
    </Card>
  )
}

// Newest first: the month the manager asked about is the one they read first.
function MovementTable({ points }: { points: TrendPoint[] }) {
  const meta = useMeta()
  const number = (value: number | null) => (value === null ? '—' : count.format(value))

  return (
    <Table>
      <TableHeader>
        <TableRow className="hover:bg-transparent">
          <TableHead>Date</TableHead>
          <TableHead className="text-right">Headcount</TableHead>
          <TableHead className="text-right">Hires</TableHead>
          <TableHead className="text-right">Exits</TableHead>
          <TableHead className="text-right">Raises</TableHead>
          <TableHead className="text-right">Raised by</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {points.toReversed().map((point) => (
          <TableRow key={point.date}>
            <TableCell className="tabular-nums">{formatDate(point.date)}</TableCell>
            <TableCell className="text-right tabular-nums">
              {count.format(point.headcount)}
              {point.salaried < point.headcount && (
                <span className="block text-xs text-muted-foreground">
                  {count.format(point.headcount - point.salaried)} without salary
                </span>
              )}
            </TableCell>
            <TableCell className="text-right tabular-nums">{number(point.hires)}</TableCell>
            <TableCell className="text-right tabular-nums">{number(point.exits)}</TableCell>
            <TableCell className="text-right tabular-nums">{number(point.raises)}</TableCell>
            <TableCell className="text-right tabular-nums">
              {point.raise_delta_cents === null ? '—' : formatMoney(point.raise_delta_cents, meta, { signed: true })}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
