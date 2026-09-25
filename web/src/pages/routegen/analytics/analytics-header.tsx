import { Link } from '@tanstack/react-router'
import type { ReactNode } from 'react'

const TABS = [
  { to: '/analytics', label: 'Overview', exact: true },
  { to: '/analytics/distribution', label: 'Distribution', exact: false },
  { to: '/analytics/outliers', label: 'Outliers', exact: false },
] as const

export function AnalyticsHeader({ description, children }: { description: ReactNode; children?: ReactNode }) {
  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="font-heading text-xl font-semibold tracking-tight">Analytics</h1>
          <p className="text-sm text-muted-foreground">{description}</p>
        </div>
        {children}
      </div>
      <nav aria-label="Analytics" className="flex gap-1 border-b">
        {TABS.map((tab) => (
          <Link
            key={tab.to}
            to={tab.to}
            activeOptions={{ exact: tab.exact, includeSearch: false }}
            className="-mb-px border-b-2 px-3 py-2 text-sm transition-colors hover:text-foreground"
            activeProps={{ className: 'border-primary font-medium text-foreground' }}
            inactiveProps={{ className: 'border-transparent text-muted-foreground' }}
          >
            {tab.label}
          </Link>
        ))}
      </nav>
    </div>
  )
}
