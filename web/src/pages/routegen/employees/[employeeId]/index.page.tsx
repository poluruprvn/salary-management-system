import { getRouteApi } from '@tanstack/react-router'
import { PencilIcon, PlusIcon, UserXIcon } from 'lucide-react'
import { type ReactNode, useState } from 'react'
import { ApiError } from '@/api/errors'
import type { Employee } from '@/api/types'
import { ErrorPanel } from '@/components/error-panel'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Empty, EmptyDescription, EmptyHeader, EmptyMedia, EmptyTitle } from '@/components/ui/empty'
import { Skeleton } from '@/components/ui/skeleton'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { useAsOf, useMeta } from '@/data/app'
import { useApi } from '@/hooks/use-api'
import { formatDate } from '@/lib/dates'
import { formatMoney } from '@/lib/money'
import { ChangeLog } from '@/pages/routegen/employees/[employeeId]/change-log'
import { EditEmployeeDialog } from '@/pages/routegen/employees/[employeeId]/edit-employee-dialog'
import { RevisionDialog } from '@/pages/routegen/employees/[employeeId]/revision-dialog'
import type { RevisionMode } from '@/pages/routegen/employees/[employeeId]/revision-schema'
import { SalaryHistory } from '@/pages/routegen/employees/[employeeId]/salary-history'
import { BackToList } from '@/pages/routegen/employees/back-to-list'
import { fetchEmployee, fetchSalaryHistory } from '@/pages/routegen/employees/data'
import { StatusBadge } from '@/pages/routegen/employees/status-badge'

const route = getRouteApi('/app/employees/$employeeId')

export function EmployeePage() {
  const { employeeId } = route.useParams()
  const { tab, changes_page } = route.useSearch()
  const navigate = route.useNavigate()
  const { asOf } = useAsOf()
  const employeeResult = useApi(['employee', employeeId, asOf], (signal) => fetchEmployee(employeeId, asOf, signal))
  const historyResult = useApi(['salary_revisions', employeeId], (signal) => fetchSalaryHistory(employeeId, signal))
  const [editing, setEditing] = useState(false)
  const [revising, setRevising] = useState<RevisionMode | null>(null)
  // Keep the page up while as_of moves, but never show one employee while another loads.
  const employee = employeeResult.data?.id === employeeId ? employeeResult.data : undefined
  const history = historyResult.data

  // Only a first load that failed. A failed reload keeps the page, and any dialog open on it.
  if (!employee && employeeResult.error) {
    return (
      <div className="flex flex-col gap-4">
        <BackToList />
        {employeeResult.error instanceof ApiError && employeeResult.error.status === 404 ? (
          <Empty className="border">
            <EmptyHeader>
              <EmptyMedia variant="icon">
                <UserXIcon />
              </EmptyMedia>
              <EmptyTitle>No such employee</EmptyTitle>
              <EmptyDescription>The link may be wrong. Search the list instead.</EmptyDescription>
            </EmptyHeader>
          </Empty>
        ) : (
          <ErrorPanel title="Could not load this employee" error={employeeResult.error} onRetry={employeeResult.retry} />
        )}
      </div>
    )
  }

  if (!employee) {
    return (
      <div className="flex flex-col gap-4">
        <BackToList />
        <Skeleton className="h-9 w-72" />
        <Skeleton className="h-28 w-full" />
        <Skeleton className="h-48 w-full" />
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-4">
        <BackToList />
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div className="flex flex-col gap-1">
            <div className="flex flex-wrap items-center gap-3">
              <h1 className="font-heading text-2xl font-semibold tracking-tight">{employee.name}</h1>
              <StatusBadge status={employee.status} />
            </div>
            <p className="text-sm text-muted-foreground">
              {employee.title} · {employee.email}
            </p>
          </div>
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => setEditing(true)}>
              <PencilIcon />
              Edit
            </Button>
            <Button onClick={() => setRevising({ kind: 'add' })} disabled={!history}>
              <PlusIcon />
              {history?.length === 0 ? 'Add starting salary' : 'Add revision'}
            </Button>
          </div>
        </div>
      </div>

      <Facts employee={employee} asOf={asOf} />

      <Tabs
        value={tab}
        onValueChange={(value) =>
          void navigate({ search: (prev) => ({ ...prev, tab: value as typeof tab }), replace: true })
        }
      >
        <TabsList variant="line">
          <TabsTrigger value="history">Salary history</TabsTrigger>
          <TabsTrigger value="changes">Change log</TabsTrigger>
        </TabsList>
        <TabsContent value="history" className="pt-2">
          <SalaryHistory employee={employee} historyResult={historyResult} onEdit={setRevising} />
        </TabsContent>
        <TabsContent value="changes" className="pt-2">
          <ChangeLog
            employeeId={employee.id}
            page={changes_page}
            onPage={(page) => void navigate({ search: (prev) => ({ ...prev, changes_page: page }) })}
          />
        </TabsContent>
      </Tabs>

      <EditEmployeeDialog employee={employee} open={editing} onOpenChange={setEditing} />
      {history && (
        <RevisionDialog employee={employee} history={history} mode={revising} onClose={() => setRevising(null)} />
      )}
    </div>
  )
}

function Facts({ employee, asOf }: { employee: Employee; asOf: string }) {
  const meta = useMeta()
  const salary = employee.current_salary

  return (
    <Card size="sm">
      <CardContent>
        <dl className="grid gap-x-6 gap-y-4 sm:grid-cols-2 lg:grid-cols-5">
          <Fact label={`Salary on ${formatDate(asOf)}`}>
            {salary ? (
              <>
                <span className="text-lg font-semibold tabular-nums">{formatMoney(salary.amount_cents, meta)}</span>
                <span className="block text-xs text-muted-foreground">since {formatDate(salary.effective_date)}</span>
              </>
            ) : (
              <span className="text-muted-foreground">{noSalaryReason(employee)}</span>
            )}
          </Fact>
          <Fact label="Department">{employee.department.name}</Fact>
          <Fact label="Country">
            {employee.country.name} <span className="text-muted-foreground">{employee.country.code}</span>
          </Fact>
          <Fact label="Level">
            {employee.level.code} <span className="text-muted-foreground">· {employee.level.name}</span>
          </Fact>
          <Fact label="Employment">
            {formatDate(employee.hire_date)} to {employee.exit_date ? formatDate(employee.exit_date) : 'present'}
          </Fact>
        </dl>
      </CardContent>
    </Card>
  )
}

function Fact({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="text-sm">{children}</dd>
    </div>
  )
}

// Salary is only ever in force on a day of employment, so a missing one says which side of it this date is.
function noSalaryReason(employee: Employee): string {
  if (employee.status === 'pending') return `Starts ${formatDate(employee.hire_date)}`
  if (employee.status === 'exited' && employee.exit_date) return `Left ${formatDate(employee.exit_date)}`

  return 'None on file'
}
