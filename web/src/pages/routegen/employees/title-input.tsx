import { type ComponentProps, useId } from 'react'
import { Input } from '@/components/ui/input'
import { useApi } from '@/hooks/use-api'
import { useDebouncedValue } from '@/hooks/use-debounced-value'
import { fetchTitles } from '@/pages/routegen/employees/data'

// Free text that offers the titles already in use, most held first, so the set converges on one spelling.
export function TitleInput({ value, ...props }: ComponentProps<'input'> & { value: string }) {
  const listId = useId()
  const q = useDebouncedValue(value.trim(), 200)
  const titles = useApi(['titles', q], (signal) => fetchTitles(q, signal))

  return (
    <>
      <Input {...props} value={value} list={listId} autoComplete="off" />
      <datalist id={listId}>
        {titles.data?.map((title) => (
          <option
            key={title.title}
            value={title.title}
            label={`${title.employee_count} ${title.employee_count === 1 ? 'person' : 'people'}`}
          />
        ))}
      </datalist>
    </>
  )
}
