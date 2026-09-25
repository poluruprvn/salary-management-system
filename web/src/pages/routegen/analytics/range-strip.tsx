import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip'
import { useMeta } from '@/data/app'
import { formatMoney } from '@/lib/money'

export type Scale = { min: number; max: number }

type RangeStripProps = {
  min: number
  p25: number
  median: number
  p75: number
  max: number
  scale: Scale
}

// Every row shares one scale, so rows compare by position, not only by the figures beside them.
export function RangeStrip({ min, p25, median, p75, max, scale }: RangeStripProps) {
  const meta = useMeta()
  const span = scale.max - scale.min || 1
  const at = (cents: number) => `${((cents - scale.min) / span) * 100}%`
  const width = (from: number, to: number) => `max(${((to - from) / span) * 100}%, 2px)`

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <div
          className="relative h-6 min-w-40"
          tabIndex={0}
          aria-label={`From ${formatMoney(min, meta)} to ${formatMoney(max, meta)}, median ${formatMoney(median, meta)}`}
        >
          <div className="absolute top-1/2 h-px -translate-y-1/2 bg-muted-foreground/50" style={{ left: at(min), width: width(min, max) }} />
          <div
            className="absolute top-1/2 h-3 -translate-y-1/2 rounded-sm bg-chart-1"
            style={{ left: at(p25), width: width(p25, p75) }}
          />
          <div
            className="absolute top-1/2 h-4 w-0.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-foreground"
            style={{ left: at(median) }}
          />
        </div>
      </TooltipTrigger>
      <TooltipContent>
        <dl className="grid grid-cols-[auto_auto] gap-x-3 tabular-nums">
          {[
            ['Max', max],
            ['75th', p75],
            ['Median', median],
            ['25th', p25],
            ['Min', min],
          ].map(([label, cents]) => (
            <div key={label} className="contents">
              <dt>{label}</dt>
              <dd className="text-right">{formatMoney(Number(cents), meta)}</dd>
            </div>
          ))}
        </dl>
      </TooltipContent>
    </Tooltip>
  )
}
