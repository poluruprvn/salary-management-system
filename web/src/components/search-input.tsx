import { SearchIcon } from 'lucide-react'
import { useEffect, useEffectEvent, useState } from 'react'
import { InputGroup, InputGroupAddon, InputGroupInput } from '@/components/ui/input-group'
import { cn } from '@/lib/utils'

type SearchInputProps = {
  value: string
  onSearch: (value: string) => void
  placeholder: string
  className?: string
}

// Holds its own text and sends it after a pause. A new value from outside, such as Back or a reset, replaces the
// text unless it is the text already sent. The page stores it trimmed, so compare trimmed.
export function SearchInput({ value, onSearch, placeholder, className }: SearchInputProps) {
  const [text, setText] = useState(value)
  const [seen, setSeen] = useState(value)

  if (value !== seen) {
    setSeen(value)
    if (value !== text.trim()) setText(value)
  }

  const search = useEffectEvent(onSearch)

  useEffect(() => {
    if (text.trim() === value) return

    const timer = setTimeout(() => search(text), 300)
    return () => clearTimeout(timer)
  }, [text, value])

  return (
    <InputGroup className={cn('sm:w-72', className)}>
      <InputGroupAddon>
        <SearchIcon />
      </InputGroupAddon>
      <InputGroupInput
        type="search"
        value={text}
        onChange={(event) => setText(event.target.value)}
        placeholder={placeholder}
        aria-label={placeholder}
      />
    </InputGroup>
  )
}
