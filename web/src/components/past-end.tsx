import type { Pagination } from '@/api/types'
import { Button } from '@/components/ui/button'
import { Empty, EmptyContent, EmptyDescription, EmptyHeader, EmptyTitle } from '@/components/ui/empty'
import { LOCALE } from '@/lib/locale'

const count = new Intl.NumberFormat(LOCALE)

export function PastEnd({ pagination, onPage }: { pagination: Pagination; onPage: (page: number) => void }) {
  const { total, total_pages } = pagination

  return (
    <Empty className="border">
      <EmptyHeader>
        <EmptyTitle>This page is past the end</EmptyTitle>
        <EmptyDescription>
          There are {total_pages} pages of {count.format(total)} {total === 1 ? 'person' : 'people'}.
        </EmptyDescription>
      </EmptyHeader>
      <EmptyContent>
        <Button variant="outline" onClick={() => onPage(total_pages)}>
          Go to the last page
        </Button>
      </EmptyContent>
    </Empty>
  )
}
