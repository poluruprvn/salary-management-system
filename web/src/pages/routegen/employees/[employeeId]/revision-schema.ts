import { z } from 'zod'
import type { Employee, Meta, SalaryHistoryEntry } from '@/api/types'
import { type Currency, formatAmount, parseMoney } from '@/lib/money'
import { REASONS } from '@/pages/routegen/employees/labels'

// The API refuses a trillion cents and up.
const MAX_CENTS = 1_000_000_000_000

export function revisionSchema(currency: Currency) {
  return z.object({
    amount: z.string().refine((text) => {
      const cents = parseMoney(text, currency)
      return cents !== null && cents > 0 && cents < MAX_CENTS
    }, 'Enter the annual amount, like 132,000 or 132,000.50'),
    effective_date: z.iso.date('Enter the date it takes effect'),
    reason: z.literal(REASONS, 'Choose a reason'),
    note: z.string(),
  })
}

export type RevisionValues = z.infer<ReturnType<typeof revisionSchema>>

export const REVISION_FIELD_ALIASES = { amount_cents: 'amount' } as const

export type RevisionMode = { kind: 'add' } | { kind: 'correct'; revision: SalaryHistoryEntry }

type DefaultsInput = {
  employee: Employee
  history: SalaryHistoryEntry[]
  mode: RevisionMode
  meta: Meta
}

export function revisionDefaults({ employee, history, mode, meta }: DefaultsInput): RevisionValues {
  if (mode.kind === 'correct') {
    const { revision } = mode
    return {
      amount: formatAmount(revision.amount_cents, meta),
      effective_date: revision.effective_date,
      reason: revision.reason,
      note: revision.note ?? '',
    }
  }
  // No reason names a hire. The seed records a starting salary this way, so the form does too.
  if (history.length === 0) {
    return { amount: '', effective_date: employee.hire_date, reason: 'market_adjustment', note: 'Starting salary' }
  }

  return { amount: '', effective_date: dateInEmployment(employee, meta.today), reason: 'merit', note: '' }
}

function dateInEmployment(employee: Employee, today: string): string {
  if (today < employee.hire_date) return employee.hire_date
  if (employee.exit_date && today > employee.exit_date) return employee.exit_date

  return today
}
