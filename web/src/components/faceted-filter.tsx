import { PlusCircleIcon } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
} from '@/components/ui/command'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Separator } from '@/components/ui/separator'

type FilterOption = { value: string; label: string; hint?: string }

type FacetedFilterProps = {
  title: string
  options: FilterOption[]
  selected: string[]
  onChange: (values: string[]) => void
}

export function FacetedFilter({ title, options, selected, onChange }: FacetedFilterProps) {
  const chosen = new Set(selected)
  const chosenOptions = options.filter((option) => chosen.has(option.value))

  function toggle(value: string) {
    const next = new Set(chosen)
    if (next.has(value)) next.delete(value)
    else next.add(value)
    onChange(options.filter((option) => next.has(option.value)).map((option) => option.value))
  }

  return (
    <Popover>
      <FilterTrigger title={title} selected={chosenOptions.map((option) => option.label)} />
      <PopoverContent className="w-60 p-0" align="start">
        <Command label={title}>
          <CommandInput placeholder={title} />
          <CommandList>
            <CommandEmpty>No match.</CommandEmpty>
            <CommandGroup>
              {options.map((option) => (
                <CommandItem
                  key={option.value}
                  value={`${option.label} ${option.hint ?? ''}`}
                  data-checked={chosen.has(option.value)}
                  onSelect={() => toggle(option.value)}
                >
                  <span>{option.label}</span>
                  {option.hint && <span className="text-xs text-muted-foreground">{option.hint}</span>}
                </CommandItem>
              ))}
            </CommandGroup>
            {chosenOptions.length > 0 && <ClearGroup onClear={() => onChange([])} />}
          </CommandList>
        </Command>
      </PopoverContent>
    </Popover>
  )
}

export function FilterTrigger({ title, selected }: { title: string; selected: string[] }) {
  return (
    <PopoverTrigger asChild>
      <Button variant="outline" size="sm" className="border-dashed">
        <PlusCircleIcon />
        {title}
        {selected.length > 0 && <Separator orientation="vertical" className="mx-0.5 data-vertical:h-4" />}
        {selected.length > 2 ? (
          <Badge variant="secondary">{selected.length} selected</Badge>
        ) : (
          selected.map((label) => (
            <Badge key={label} variant="secondary" className="max-w-48 truncate">
              {label}
            </Badge>
          ))
        )}
      </Button>
    </PopoverTrigger>
  )
}

export function ClearGroup({ onClear }: { onClear: () => void }) {
  return (
    <>
      <CommandSeparator />
      <CommandGroup>
        <CommandItem onSelect={onClear} className="justify-center">
          Clear
        </CommandItem>
      </CommandGroup>
    </>
  )
}
