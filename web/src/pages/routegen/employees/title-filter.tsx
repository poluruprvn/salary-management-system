import { useState } from 'react'
import { ClearGroup, FilterTrigger } from '@/components/faceted-filter'
import { Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from '@/components/ui/command'
import { Popover, PopoverContent } from '@/components/ui/popover'
import { Spinner } from '@/components/ui/spinner'
import { useApi } from '@/hooks/use-api'
import { useDebouncedValue } from '@/hooks/use-debounced-value'
import { errorMessage } from '@/lib/errors'
import { fetchTitles } from '@/pages/routegen/employees/data'

export function TitleFilter({ value, onChange }: { value?: string; onChange: (title?: string) => void }) {
  const [open, setOpen] = useState(false)
  const [text, setText] = useState('')
  const q = useDebouncedValue(text.trim(), 200)
  const titles = useApi(['titles', q], (signal) => fetchTitles(q, signal), { enabled: open })

  function choose(title?: string) {
    onChange(title)
    setOpen(false)
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <FilterTrigger title="Title" selected={value ? [value] : []} />
      <PopoverContent className="w-80 p-0" align="start">
        <Command shouldFilter={false} label="Titles">
          <CommandInput placeholder="Search titles" value={text} onValueChange={setText} />
          <CommandList>
            {!!titles.error && <p className="px-2 py-6 text-center text-sm text-destructive">{errorMessage(titles.error)}</p>}
            {!titles.error && !titles.data && (
              <div className="flex justify-center py-6">
                <Spinner />
              </div>
            )}
            {titles.data && <CommandEmpty>No title matches.</CommandEmpty>}
            <CommandGroup>
              {titles.data?.map((title) => (
                <CommandItem
                  key={title.title}
                  value={title.title}
                  data-checked={title.title === value}
                  onSelect={() => choose(title.title === value ? undefined : title.title)}
                >
                  <span className="flex-1 truncate">{title.title}</span>
                  <span className="text-xs text-muted-foreground tabular-nums">{title.employee_count}</span>
                </CommandItem>
              ))}
            </CommandGroup>
            {value && <ClearGroup onClear={() => choose(undefined)} />}
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  )
}
