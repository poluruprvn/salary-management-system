import type { EmployeeStatus, Level, SalaryReason } from '@/api/types'

// Records, so a value added to the API contract fails the build until it has a label.
export const STATUS_LABELS: Record<EmployeeStatus, string> = { active: 'Active', pending: 'Pending', exited: 'Exited' }

export const REASON_LABELS: Record<SalaryReason, string> = {
  merit: 'Merit',
  promotion: 'Promotion',
  market_adjustment: 'Market adjustment',
  correction: 'Correction',
}

export const REASONS = Object.keys(REASON_LABELS) as SalaryReason[]

export function levelLabel(level: Level): string {
  return `${level.code} · ${level.name}`
}
