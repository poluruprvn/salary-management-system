import { MoreHorizontalIcon, PlusIcon, WalletIcon } from 'lucide-react'
import { useState } from 'react'
import type { Employee, SalaryHistoryEntry } from '@/api/types'
import { ErrorPanel } from '@/components/error-panel'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Empty, EmptyContent, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle } from '@/components/ui/empty'
import { Skeleton } from '@/components/ui/skeleton'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useAsOf, useMeta } from '@/data/app'
import type { ApiResult } from '@/hooks/use-api'
import { formatDate } from '@/lib/dates'
import { formatChange, formatMoney } from '@/lib/money'
import { REASON_LABELS } from '@/pages/routegen/employees/labels'
import type { RevisionMode } from '@/pages/routegen/employees/[employeeId]/revision-schema'
import { VoidRevisionDialog } from '@/pages/routegen/employees/[employeeId]/void-revision-dialog'

type SalaryHistoryProps = {
  employee: Employee
  historyResult: ApiResult<SalaryHistoryEntry[]>
  onEdit: (mode: RevisionMode) => void
}

export function SalaryHistory({ employee, historyResult, onEdit }: SalaryHistoryProps) {
  const meta = useMeta()
  const { asOf } = useAsOf()
  const [voiding, setVoiding] = useState<SalaryHistoryEntry | null>(null)

  const entries = historyResult.data
  // Only a first load that failed. A failed reload keeps the table, and the void dialog open on it.
  if (!entries && historyResult.error) {
    return <ErrorPanel title="Could not load the salary history" error={historyResult.error} onRetry={historyResult.retry} />
  }
  if (!entries) return <Skeleton className="h-40 w-full" />

  // The API answers which revision is in force, so the client never re-derives the employment window.
  const inForce = employee.current_salary?.effective_date

  return (
    <>
      {entries.length === 0 ? (
        <Empty className="border">
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <WalletIcon />
            </EmptyMedia>
            <EmptyTitle>No salary on file</EmptyTitle>
            <EmptyDescription>Set the starting salary. Later raises are added as new revisions.</EmptyDescription>
          </EmptyHeader>
          <EmptyContent>
            <Button onClick={() => onEdit({ kind: 'add' })}>
              <PlusIcon />
              Add starting salary
            </Button>
          </EmptyContent>
        </Empty>
      ) : (
        <div className="overflow-hidden rounded-lg border">
          <Table>
            <TableHeader>
              <TableRow className="hover:bg-transparent">
                <TableHead>Effective</TableHead>
                <TableHead className="text-right">Salary</TableHead>
                <TableHead className="text-right">Previous</TableHead>
                <TableHead className="text-right">Change</TableHead>
                <TableHead>Reason</TableHead>
                <TableHead>Note</TableHead>
                <TableHead>
                  <span className="sr-only">Actions</span>
                </TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {entries.map((entry) => (
                <TableRow key={entry.id}>
                  <TableCell>
                    <div className="flex items-center gap-2">
                      <span className="tabular-nums">{formatDate(entry.effective_date)}</span>
                      {entry.effective_date === inForce && <Badge>In force</Badge>}
                      {entry.effective_date > asOf && <Badge variant="outline">Scheduled</Badge>}
                    </div>
                  </TableCell>
                  <TableCell className="text-right font-medium tabular-nums">
                    {formatMoney(entry.amount_cents, meta)}
                  </TableCell>
                  <TableCell className="text-right text-muted-foreground tabular-nums">
                    {entry.previous_amount_cents === null ? '—' : formatMoney(entry.previous_amount_cents, meta)}
                  </TableCell>
                  <TableCell className="text-right tabular-nums">
                    {entry.previous_amount_cents === null ? (
                      <span className="text-muted-foreground">First on file</span>
                    ) : (
                      <>
                        {formatMoney(entry.amount_cents - entry.previous_amount_cents, meta, { signed: true })}
                        <span className="ml-1.5 text-muted-foreground">
                          {formatChange(entry.amount_cents, entry.previous_amount_cents)}
                        </span>
                      </>
                    )}
                  </TableCell>
                  <TableCell>{REASON_LABELS[entry.reason]}</TableCell>
                  <TableCell className="max-w-64 truncate text-muted-foreground" title={entry.note ?? undefined}>
                    {entry.note ?? ''}
                  </TableCell>
                  <TableCell className="w-10 text-right">
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="icon-sm" aria-label={`Actions for ${formatDate(entry.effective_date)}`}>
                          <MoreHorizontalIcon />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        <DropdownMenuItem onSelect={() => onEdit({ kind: 'correct', revision: entry })}>
                          Correct…
                        </DropdownMenuItem>
                        <DropdownMenuItem variant="destructive" onSelect={() => setVoiding(entry)}>
                          Void…
                        </DropdownMenuItem>
                      </DropdownMenuContent>
                    </DropdownMenu>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </div>
      )}
      <VoidRevisionDialog employeeId={employee.id} revision={voiding} onClose={() => setVoiding(null)} />
    </>
  )
}
