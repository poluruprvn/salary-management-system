import { useSession } from '@/auth/session'
import type { EmployeeListSearch } from '@/pages/routegen/employees/search'

// The list's last search, so the employee page links back to the same filters and page.
let lastSearch: Partial<EmployeeListSearch> = {}

export function rememberListSearch(search: EmployeeListSearch) {
  lastSearch = search
}

export function lastListSearch(): Partial<EmployeeListSearch> {
  return lastSearch
}

// Nothing from a session outlives it, so the next manager's back link starts clean.
export function clearListSearchOnSignOut() {
  useSession.subscribe((session) => {
    if (!session.refreshToken) lastSearch = {}
  })
}
