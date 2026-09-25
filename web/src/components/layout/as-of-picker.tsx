import { useNavigate } from '@tanstack/react-router'
import { CalendarClockIcon } from 'lucide-react'
import { useEffect, useEffectEvent, useState } from 'react'
import { Button } from '@/components/ui/button'
import { InputGroup, InputGroupAddon, InputGroupInput } from '@/components/ui/input-group'
import { useAsOf } from '@/data/app'

// Chrome fires change on each keystroke in the year segment, and year 0002 is a date the API would answer.
const PLAUSIBLE_DATE = /^(19|20)\d{2}-\d{2}-\d{2}$/

export function AsOfPicker() {
  const { asOf, today } = useAsOf()
  const navigate = useNavigate()
  const [draft, setDraft] = useState(asOf)
  const [seen, setSeen] = useState(asOf)

  if (asOf !== seen) {
    setSeen(asOf)
    setDraft(asOf)
  }

  function commit(value: string) {
    if (value === asOf || !PLAUSIBLE_DATE.test(value)) return

    // undefined, not a missing key: retainSearchParams puts a missing as_of back.
    void navigate({ to: '.', search: (prev) => ({ ...prev, as_of: value === today ? undefined : value }) })
  }

  const commitAfterPause = useEffectEvent(commit)

  useEffect(() => {
    const timer = setTimeout(() => commitAfterPause(draft), 800)
    return () => clearTimeout(timer)
  }, [draft])

  return (
    <div className="flex items-center gap-1">
      <InputGroup className="w-auto">
        <InputGroupAddon>
          <CalendarClockIcon />
          <label htmlFor="as-of" className="text-muted-foreground">
            As of
          </label>
        </InputGroupAddon>
        <InputGroupInput
          id="as-of"
          type="date"
          value={draft}
          onChange={(event) => setDraft(event.target.value)}
          onBlur={() => (PLAUSIBLE_DATE.test(draft) ? commit(draft) : setDraft(asOf))}
          onKeyDown={(event) => event.key === 'Enter' && commit(draft)}
          className="w-34"
        />
      </InputGroup>
      {asOf !== today && (
        <Button variant="ghost" size="sm" onClick={() => commit(today)}>
          Today
        </Button>
      )}
    </div>
  )
}
