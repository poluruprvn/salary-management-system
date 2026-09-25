import { ChevronLeftIcon, ChevronRightIcon } from 'lucide-react'
import { useState } from 'react'
import type { Pagination } from '@/api/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { pageNumbers } from '@/lib/page-numbers'

export function PageNav({ pagination, onPage }: { pagination: Pagination; onPage: (page: number) => void }) {
  const { page, total_pages, prev_page, next_page } = pagination
  if (total_pages <= 1) return null

  return (
    <nav aria-label="Pages" className="flex flex-wrap items-center gap-1">
      <Button
        variant="ghost"
        size="sm"
        disabled={prev_page === null}
        onClick={() => prev_page && onPage(prev_page)}
        aria-label="Previous page"
      >
        <ChevronLeftIcon />
      </Button>
      {pageNumbers(Math.min(page, total_pages), total_pages).map((entry, index) =>
        entry === 'gap' ? (
          <span key={`gap-${index}`} className="px-1 text-muted-foreground" aria-hidden>
            …
          </span>
        ) : (
          <Button
            key={entry}
            variant={entry === page ? 'outline' : 'ghost'}
            size="sm"
            className="min-w-8 tabular-nums"
            aria-current={entry === page ? 'page' : undefined}
            onClick={() => onPage(entry)}
          >
            {entry}
          </Button>
        ),
      )}
      <Button
        variant="ghost"
        size="sm"
        disabled={next_page === null}
        onClick={() => next_page && onPage(next_page)}
        aria-label="Next page"
      >
        <ChevronRightIcon />
      </Button>
      <PageJump total={total_pages} onPage={onPage} />
    </nav>
  )
}

// Offset paging exists so a manager can jump straight to a page, so there is a box for it.
function PageJump({ total, onPage }: { total: number; onPage: (page: number) => void }) {
  const [text, setText] = useState('')

  return (
    <form
      className="ml-2 flex items-center gap-1.5 text-sm text-muted-foreground"
      onSubmit={(event) => {
        event.preventDefault()
        const target = Number(text)
        if (Number.isInteger(target) && target >= 1) onPage(Math.min(target, total))
        setText('')
      }}
    >
      <label htmlFor="page-jump">Go to</label>
      <Input
        id="page-jump"
        inputMode="numeric"
        value={text}
        onChange={(event) => setText(event.target.value)}
        className="h-7 w-14 text-center tabular-nums"
        placeholder="page"
      />
    </form>
  )
}
