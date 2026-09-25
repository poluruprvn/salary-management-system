import { ArrowDownIcon, ArrowUpIcon, ChevronsUpDownIcon } from 'lucide-react'
import type { ReactNode } from 'react'
import { Button } from '@/components/ui/button'
import { TableHead } from '@/components/ui/table'
import { cn } from '@/lib/utils'

const SORT_ICONS = { ascending: ArrowUpIcon, descending: ArrowDownIcon, none: ChevronsUpDownIcon }

type SortableHeadProps<K extends string> = {
  sortKey: K
  sort: string
  onSort: (sort: K | `-${K}`) => void
  align?: 'right'
  className?: string
  children: ReactNode
}

export function SortableHead<K extends string>({
  sortKey,
  sort,
  onSort,
  align,
  className,
  children,
}: SortableHeadProps<K>) {
  const direction = sortDirection(sort, sortKey)
  const Icon = SORT_ICONS[direction]

  return (
    <TableHead aria-sort={direction} className={cn(align === 'right' && 'text-right', className)}>
      <Button
        variant="ghost"
        size="sm"
        className={cn('-mx-2 h-7 px-2 font-medium', align === 'right' && 'flex-row-reverse')}
        onClick={() => onSort(direction === 'ascending' ? `-${sortKey}` : sortKey)}
      >
        {children}
        <Icon className={cn(direction === 'none' && 'text-muted-foreground/60')} />
      </Button>
    </TableHead>
  )
}

function sortDirection(sort: string, key: string): 'ascending' | 'descending' | 'none' {
  if (sort === key) return 'ascending'
  if (sort === `-${key}`) return 'descending'

  return 'none'
}
