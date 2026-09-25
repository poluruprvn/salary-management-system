import { Link } from '@tanstack/react-router'
import { ArrowLeftIcon } from 'lucide-react'
import { lastListSearch } from '@/pages/routegen/employees/list-store'

export function BackToList() {
  return (
    <Link
      to="/employees"
      search={lastListSearch()}
      className="inline-flex w-fit items-center gap-1.5 text-sm text-muted-foreground transition-colors hover:text-foreground"
    >
      <ArrowLeftIcon className="size-4" />
      All employees
    </Link>
  )
}
