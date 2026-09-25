import { zodResolver } from '@hookform/resolvers/zod'
import { ArrowRightIcon } from 'lucide-react'
import { useState } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { toast } from 'sonner'
import type { Employee, SalaryChange, SalaryHistoryEntry } from '@/api/types'
import { FormField, SelectInput } from '@/components/form-field'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { FieldGroup } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { InputGroup, InputGroupAddon, InputGroupInput, InputGroupText } from '@/components/ui/input-group'
import { Spinner } from '@/components/ui/spinner'
import { Textarea } from '@/components/ui/textarea'
import { useMeta } from '@/data/app'
import { formatDate } from '@/lib/dates'
import { applyApiErrors } from '@/lib/errors'
import { pickDirty } from '@/lib/forms'
import { type Currency, formatChange, formatMoney, parseMoney } from '@/lib/money'
import {
  REVISION_FIELD_ALIASES,
  type RevisionMode,
  type RevisionValues,
  revisionDefaults,
  revisionSchema,
} from '@/pages/routegen/employees/[employeeId]/revision-schema'
import { addRevision, correctRevision } from '@/pages/routegen/employees/data'
import { REASON_LABELS, REASONS } from '@/pages/routegen/employees/labels'

const REASON_OPTIONS = REASONS.map((reason) => ({ value: reason, label: REASON_LABELS[reason] }))

type RevisionDialogProps = {
  employee: Employee
  history: SalaryHistoryEntry[]
  mode: RevisionMode | null
  onClose: () => void
}

export function RevisionDialog({ employee, history, mode, onClose }: RevisionDialogProps) {
  // Open until the save answers, so a failure has somewhere to show.
  const [saving, setSaving] = useState(false)

  return (
    <Dialog open={mode !== null} onOpenChange={(open) => !open && !saving && onClose()}>
      <DialogContent className="sm:max-w-md">
        {mode && (
          <RevisionForm employee={employee} history={history} mode={mode} onSaving={setSaving} onDone={onClose} />
        )}
      </DialogContent>
    </Dialog>
  )
}

type RevisionFormProps = {
  employee: Employee
  history: SalaryHistoryEntry[]
  mode: RevisionMode
  onSaving: (saving: boolean) => void
  onDone: () => void
}

function RevisionForm({ employee, history, mode, onSaving, onDone }: RevisionFormProps) {
  const meta = useMeta()
  const correcting = mode.kind === 'correct' ? mode.revision : undefined
  const form = useForm<RevisionValues>({
    resolver: zodResolver(revisionSchema(meta)),
    defaultValues: revisionDefaults({ employee, history, mode, meta }),
  })
  const [alert, setAlert] = useState<string | null>(null)

  const [amountText, effectiveDate] = useWatch({ control: form.control, name: ['amount', 'effective_date'] })
  // History is newest first, so this is the revision in force the day before the new one.
  const previous = history.find((entry) => entry.id !== correcting?.id && entry.effective_date < effectiveDate)

  const onSubmit = form.handleSubmit(async (values) => {
    setAlert(null)
    const body = {
      amount_cents: parseMoney(values.amount, meta) ?? 0,
      effective_date: values.effective_date,
      reason: values.reason,
      note: values.note.trim() || null,
    }

    onSaving(true)
    try {
      if (correcting) {
        const dirty = form.formState.dirtyFields
        const patch = pickDirty(body, { ...dirty, amount_cents: dirty.amount })
        if (Object.keys(patch).length > 0) {
          await correctRevision(employee.id, correcting.id, patch)
          toast.success('Revision corrected')
        }
      } else {
        // The server's previous amount, not the preview's: it is the one on file.
        const change = await addRevision(employee.id, body)
        toast.success(`${formatMoney(change.amount_cents, meta)} from ${formatDate(change.effective_date)}`, {
          description: changeSummary(change, meta),
        })
      }
      onDone()
    } catch (error) {
      setAlert(applyApiErrors(error, form, REVISION_FIELD_ALIASES))
    } finally {
      onSaving(false)
    }
  })

  return (
    <form onSubmit={onSubmit} noValidate className="grid gap-4">
      <DialogHeader>
        <DialogTitle>{formTitle(mode, history)}</DialogTitle>
        <DialogDescription>
          {correcting
            ? 'For fixing a mistake. A raise is a new revision, not a correction.'
            : 'A raise is a new revision. The salary before it stays on file.'}
        </DialogDescription>
      </DialogHeader>
      <FieldGroup className="gap-4">
        {alert && (
          <Alert variant="destructive">
            <AlertDescription>{alert}</AlertDescription>
          </Alert>
        )}
        <FormField control={form.control} name="amount" label="Annual salary">
          {(input) => (
            <InputGroup>
              <InputGroupAddon>
                <InputGroupText>{meta.base_currency}</InputGroupText>
              </InputGroupAddon>
              <InputGroupInput
                {...input}
                inputMode="decimal"
                autoComplete="off"
                placeholder="132,000"
                autoFocus
                className="tabular-nums"
              />
              <InputGroupAddon align="inline-end">
                <InputGroupText>per year</InputGroupText>
              </InputGroupAddon>
            </InputGroup>
          )}
        </FormField>
        <div className="grid gap-4 sm:grid-cols-2">
          <FormField control={form.control} name="effective_date" label="Effective date">
            {(input) => <Input {...input} type="date" />}
          </FormField>
          <FormField control={form.control} name="reason" label="Reason">
            {(input) => <SelectInput {...input} options={REASON_OPTIONS} />}
          </FormField>
        </div>
        <FormField control={form.control} name="note" label="Note" description="Optional. Kept with the revision.">
          {(input) => <Textarea {...input} rows={2} />}
        </FormField>
        <Preview
          previous={previous}
          amount={parseMoney(amountText, meta)}
          effectiveDate={effectiveDate}
          currency={meta}
        />
      </FieldGroup>
      <DialogFooter>
        <DialogClose asChild>
          <Button variant="outline" type="button" disabled={form.formState.isSubmitting}>
            Cancel
          </Button>
        </DialogClose>
        <Button type="submit" disabled={form.formState.isSubmitting}>
          {form.formState.isSubmitting && <Spinner />}
          {correcting ? 'Save correction' : 'Save revision'}
        </Button>
      </DialogFooter>
    </form>
  )
}

function formTitle(mode: RevisionMode, history: SalaryHistoryEntry[]): string {
  if (mode.kind === 'correct') return 'Correct revision'
  if (history.length === 0) return 'Set starting salary'

  return 'Add salary revision'
}

function changeSummary(change: SalaryChange, currency: Currency): string {
  if (change.previous_amount_cents === null) return 'The first salary on file.'

  const before = formatMoney(change.previous_amount_cents, currency)
  const after = formatMoney(change.amount_cents, currency)
  return `${before} to ${after}, ${formatChange(change.amount_cents, change.previous_amount_cents)}.`
}

type PreviewProps = {
  previous: SalaryHistoryEntry | undefined
  amount: number | null
  effectiveDate: string
  currency: Currency
}

// What the change will read as, from the history already on screen. The server has the final word on save.
function Preview({ previous, amount, effectiveDate, currency }: PreviewProps) {
  if (!previous) {
    return (
      <div aria-live="polite" className="rounded-lg bg-muted/60 px-3 py-2.5 text-sm text-muted-foreground">
        No salary is on file before this date.
      </div>
    )
  }

  return (
    <div
      aria-live="polite"
      className="flex flex-wrap items-center gap-x-2 gap-y-1 rounded-lg bg-muted/60 px-3 py-2.5 text-sm"
    >
      <span className="text-muted-foreground">In force before {effectiveDate ? formatDate(effectiveDate) : 'then'}</span>
      <span className="font-medium tabular-nums">{formatMoney(previous.amount_cents, currency)}</span>
      {amount !== null && amount > 0 && (
        <>
          <ArrowRightIcon className="size-3.5 text-muted-foreground" aria-label="to" />
          <span className="font-medium tabular-nums">{formatMoney(amount, currency)}</span>
          <span className="text-muted-foreground tabular-nums">
            {formatMoney(amount - previous.amount_cents, currency, { signed: true })},{' '}
            {formatChange(amount, previous.amount_cents)}
          </span>
        </>
      )}
    </div>
  )
}
