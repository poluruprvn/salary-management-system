import type { EmployeeStatus } from '@/api/types'
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'
import { STATUS_LABELS } from '@/pages/routegen/employees/labels'

export function StatusBadge({ status }: { status: EmployeeStatus }) {
  return (
    <Badge variant={status === 'active' ? 'outline' : 'secondary'} className={cn(status === 'exited' && 'text-muted-foreground')}>
      <span
        aria-hidden
        className={cn(
          'size-1.5 rounded-full',
          status === 'active' && 'bg-primary',
          status === 'pending' && 'border border-muted-foreground',
          status === 'exited' && 'bg-muted-foreground/60',
        )}
      />
      {STATUS_LABELS[status]}
    </Badge>
  )
}
