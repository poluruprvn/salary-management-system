import { Link, useNavigate } from '@tanstack/react-router'
import type { Employee, EmployeeSort } from '@/api/types'
import { SortableHead } from '@/components/sortable-head'
import { Skeleton } from '@/components/ui/skeleton'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip'
import { useMeta } from '@/data/app'
import { formatDate } from '@/lib/dates'
import { formatMoney } from '@/lib/money'
import { StatusBadge } from '@/pages/routegen/employees/status-badge'

const COLUMN_COUNT = 9

type EmployeeTableProps = {
  employees: Employee[] | undefined
  perPage: number
  sort: EmployeeSort
  onSort: (sort: EmployeeSort) => void
}

export function EmployeeTable({ employees, perPage, sort, onSort }: EmployeeTableProps) {
  const meta = useMeta()
  const navigate = useNavigate()
  const sorting = { sort, onSort }

  return (
    <Table>
      <TableHeader>
        <TableRow className="hover:bg-transparent">
          <SortableHead sortKey="name" {...sorting}>
            Name
          </SortableHead>
          <TableHead>Title</TableHead>
          <SortableHead sortKey="department" {...sorting}>
            Department
          </SortableHead>
          <SortableHead sortKey="country" {...sorting}>
            Country
          </SortableHead>
          <SortableHead sortKey="level" {...sorting}>
            Level
          </SortableHead>
          <TableHead>Status</TableHead>
          <SortableHead sortKey="hire_date" {...sorting}>
            Hired
          </SortableHead>
          <SortableHead sortKey="exit_date" {...sorting}>
            Exit
          </SortableHead>
          <SortableHead sortKey="salary" align="right" {...sorting}>
            Salary
          </SortableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {employees
          ? employees.map((employee) => (
              <TableRow
                key={employee.id}
                className="cursor-pointer focus-within:bg-muted/50"
                onClick={(event) => {
                  // The name is the real link. A click elsewhere on the row follows it, unless it ends a text selection.
                  const onControl = (event.target as HTMLElement).closest('a, button')
                  const selecting = Boolean(window.getSelection()?.toString())
                  if (onControl || selecting) return
                  void navigate({ to: '/employees/$employeeId', params: { employeeId: employee.id } })
                }}
              >
                <TableCell className="max-w-64">
                  <Link
                    to="/employees/$employeeId"
                    params={{ employeeId: employee.id }}
                    className="block truncate font-medium outline-none hover:underline focus-visible:underline"
                  >
                    {employee.name}
                  </Link>
                  <div className="truncate text-xs text-muted-foreground">{employee.email}</div>
                </TableCell>
                <TableCell className="max-w-56 truncate">{employee.title}</TableCell>
                <TableCell>{employee.department.name}</TableCell>
                <TableCell>{employee.country.name}</TableCell>
                <TableCell>
                  <Tooltip>
                    <TooltipTrigger asChild>
                      <span className="font-mono text-xs">{employee.level.code}</span>
                    </TooltipTrigger>
                    <TooltipContent>{employee.level.name}</TooltipContent>
                  </Tooltip>
                </TableCell>
                <TableCell>
                  <StatusBadge status={employee.status} />
                </TableCell>
                <TableCell className="tabular-nums">{formatDate(employee.hire_date)}</TableCell>
                <TableCell className="text-muted-foreground tabular-nums">
                  {employee.exit_date ? formatDate(employee.exit_date) : '—'}
                </TableCell>
                <TableCell className="text-right font-medium tabular-nums">
                  {employee.current_salary ? formatMoney(employee.current_salary.amount_cents, meta) : '—'}
                </TableCell>
              </TableRow>
            ))
          : Array.from({ length: Math.min(perPage, 10) }, (_, row) => (
              <TableRow key={row}>
                {Array.from({ length: COLUMN_COUNT }, (_, cell) => (
                  <TableCell key={cell}>
                    <Skeleton className="h-4 w-full max-w-28" />
                  </TableCell>
                ))}
              </TableRow>
            ))}
      </TableBody>
    </Table>
  )
}
