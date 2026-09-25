import { ArrowRightIcon, HistoryIcon } from 'lucide-react'
import type { Audit, SalaryReason } from '@/api/types'
import { ErrorPanel } from '@/components/error-panel'
import { PageNav } from '@/components/page-nav'
import { Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle } from '@/components/ui/empty'
import { Skeleton } from '@/components/ui/skeleton'
import { useClosedSets, useMeta } from '@/data/app'
import { useApi } from '@/hooks/use-api'
import { formatDate, formatTimestamp } from '@/lib/dates'
import { formatMoney } from '@/lib/money'
import { fetchAudits } from '@/pages/routegen/employees/data'
import { levelLabel, REASON_LABELS } from '@/pages/routegen/employees/labels'

// In display order. A field not listed here is not shown.
const FIELD_LABELS: Record<string, string> = {
  name: 'Name',
  email: 'Email',
  title: 'Title',
  hire_date: 'Hire date',
  exit_date: 'Exit date',
  department_id: 'Department',
  country_id: 'Country',
  level_id: 'Level',
  amount_cents: 'Salary',
  effective_date: 'Effective date',
  reason: 'Reason',
  note: 'Note',
}

function shownFields(audit: Audit): [string, unknown][] {
  const changes = audit.audited_changes

  return Object.keys(FIELD_LABELS)
    .filter((field) => field in changes && (audit.action === 'update' || isPresent(changes[field])))
    .map((field) => [field, changes[field]])
}

function isPresent(value: unknown): boolean {
  return value !== null && value !== undefined && value !== ''
}

function useFormatValue() {
  const { departments, countries, levels } = useClosedSets()
  const meta = useMeta()

  return (field: string, value: unknown): string => {
    if (!isPresent(value)) return '—'

    switch (field) {
      case 'amount_cents':
        return formatMoney(Number(value), meta)
      case 'hire_date':
      case 'exit_date':
      case 'effective_date':
        return formatDate(String(value))
      case 'department_id':
        return departments.find((department) => department.id === value)?.name ?? String(value)
      case 'country_id':
        return countries.find((country) => country.id === value)?.name ?? String(value)
      case 'level_id': {
        const level = levels.find((candidate) => candidate.id === value)
        return level ? levelLabel(level) : String(value)
      }
      case 'reason':
        return REASON_LABELS[value as SalaryReason] ?? String(value)
      default:
        return String(value)
    }
  }
}

// An update records each changed field as [old, new]. A create records each field's value.
function isChange(value: unknown): value is [unknown, unknown] {
  return Array.isArray(value) && value.length === 2
}

function headline(audit: Audit): string {
  if (audit.auditable_type === 'employee') return audit.action === 'create' ? 'Added the employee' : 'Updated the employee'
  if (audit.action === 'create') return 'Added a salary revision'

  const voided = audit.audited_changes.voided_at
  if (isChange(voided)) return voided[1] === null ? 'Restored a salary revision' : 'Voided a salary revision'

  return 'Corrected a salary revision'
}

type ChangeLogProps = {
  employeeId: string
  page: number
  onPage: (page: number) => void
}

export function ChangeLog({ employeeId, page, onPage }: ChangeLogProps) {
  const auditsResult = useApi(['audits', employeeId, page], (signal) => fetchAudits(employeeId, page, signal))
  const formatValue = useFormatValue()

  if (auditsResult.error) {
    return <ErrorPanel title="Could not load the change log" error={auditsResult.error} onRetry={auditsResult.retry} />
  }
  if (!auditsResult.data) return <Skeleton className="h-40 w-full" />

  const { data, pagination } = auditsResult.data
  if (pagination.total === 0) {
    return (
      <Empty className="border">
        <EmptyHeader>
          <EmptyMedia variant="icon">
            <HistoryIcon />
          </EmptyMedia>
          <EmptyTitle>No changes recorded</EmptyTitle>
          <EmptyDescription>Edits made through the app appear here, with who made them.</EmptyDescription>
        </EmptyHeader>
      </Empty>
    )
  }

  return (
    <div className="flex flex-col gap-3">
      <ol className="divide-y rounded-lg border">
        {data.map((audit) => {
          const fields = shownFields(audit)

          return (
            <li key={audit.id} className="flex flex-col gap-2 px-4 py-3 sm:flex-row sm:gap-6">
              <div className="shrink-0 text-sm sm:w-60">
                <div className="font-medium">{headline(audit)}</div>
                <time dateTime={audit.created_at} className="block text-muted-foreground">
                  {formatTimestamp(audit.created_at)}
                </time>
                <div className="text-muted-foreground">by {audit.user?.name ?? 'System'}</div>
              </div>
              {fields.length > 0 && (
                <dl className="grid flex-1 grid-cols-[minmax(7rem,auto)_1fr] content-start gap-x-4 gap-y-1 text-sm">
                  {fields.map(([field, value]) => (
                    <div key={field} className="contents">
                      <dt className="text-muted-foreground">{FIELD_LABELS[field]}</dt>
                      <dd className="flex flex-wrap items-center gap-1.5">
                        {isChange(value) && audit.action === 'update' ? (
                          <>
                            <span className="text-muted-foreground line-through decoration-muted-foreground/50">
                              {formatValue(field, value[0])}
                            </span>
                            <ArrowRightIcon className="size-3.5 text-muted-foreground" aria-label="changed to" />
                            <span>{formatValue(field, value[1])}</span>
                          </>
                        ) : (
                          formatValue(field, value)
                        )}
                      </dd>
                    </div>
                  ))}
                </dl>
              )}
            </li>
          )
        })}
      </ol>
      <div className="flex justify-end">
        <PageNav pagination={pagination} onPage={onPage} />
      </div>
    </div>
  )
}
