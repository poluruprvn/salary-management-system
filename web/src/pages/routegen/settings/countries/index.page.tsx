import { zodResolver } from '@hookform/resolvers/zod'
import { useRouter } from '@tanstack/react-router'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { z } from 'zod'
import type { Country } from '@/api/types'
import { Button } from '@/components/ui/button'
import { Field, FieldError } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Spinner } from '@/components/ui/spinner'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useClosedSets } from '@/data/app'
import { applyApiErrors } from '@/lib/errors'
import { updateMultiplier } from '@/pages/routegen/settings/countries/data'

// Mirrors the API: above 0, below 100, at most four places. The API checks it again.
const multiplierSchema = z.object({
  employer_cost_multiplier: z
    .string()
    .trim()
    .regex(/^\d{1,2}(\.\d{1,4})?$/, 'Use a number below 100 with at most 4 decimal places')
    .refine((value) => Number(value) > 0, 'Must be above 0'),
})

type MultiplierValues = z.infer<typeof multiplierSchema>

export function CountriesPage() {
  const { countries } = useClosedSets()

  return (
    <div className="flex flex-col gap-4">
      <div>
        <h1 className="font-heading text-xl font-semibold tracking-tight">Countries</h1>
        <p className="max-w-2xl text-sm text-muted-foreground">
          The employer cost multiplier turns gross salary into fully loaded cost. It is not dated, so a change applies to
          every date, past ones included.
        </p>
      </div>
      <div className="overflow-hidden rounded-lg border">
        <Table>
          <TableHeader>
            <TableRow className="hover:bg-transparent">
              <TableHead className="w-20">Code</TableHead>
              <TableHead>Name</TableHead>
              <TableHead className="w-96">Employer cost multiplier</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {countries.map((country) => (
              // Keyed on the value too, so a saved row starts clean from what the server now holds.
              <CountryRow key={`${country.id}:${country.employer_cost_multiplier}`} country={country} />
            ))}
          </TableBody>
        </Table>
      </div>
    </div>
  )
}

function CountryRow({ country }: { country: Country }) {
  const router = useRouter()
  const form = useForm<MultiplierValues>({
    resolver: zodResolver(multiplierSchema),
    defaultValues: { employer_cost_multiplier: country.employer_cost_multiplier },
  })
  const [alert, setAlert] = useState<string | null>(null)
  const error = form.formState.errors.employer_cost_multiplier?.message ?? alert
  const inputId = `multiplier-${country.id}`

  const onSubmit = form.handleSubmit(async ({ employer_cost_multiplier }) => {
    setAlert(null)
    try {
      const saved = await updateMultiplier(country.id, employer_cost_multiplier)
      toast.success(
        `Fully loaded figures now use ${saved.employer_cost_multiplier} for ${saved.name}, including past months.`,
      )
      // The closed sets come from the app route's loader, which keeps them for an hour.
      await router.invalidate()
    } catch (caught) {
      setAlert(applyApiErrors(caught, form))
    }
  })

  return (
    <TableRow className="hover:bg-transparent">
      <TableCell className="font-mono text-xs">{country.code}</TableCell>
      <TableCell>
        <label htmlFor={inputId}>{country.name}</label>
      </TableCell>
      <TableCell>
        <form onSubmit={onSubmit} noValidate>
          <Field data-invalid={!!error} className="gap-1">
            <div className="flex items-center gap-2">
              <Input
                {...form.register('employer_cost_multiplier')}
                id={inputId}
                inputMode="decimal"
                autoComplete="off"
                aria-invalid={!!error}
                className="w-28 tabular-nums"
              />
              <Button
                type="submit"
                size="sm"
                variant="outline"
                disabled={!form.formState.isDirty || form.formState.isSubmitting}
              >
                {form.formState.isSubmitting && <Spinner />}
                Save
              </Button>
            </div>
            {error && <FieldError>{error}</FieldError>}
          </Field>
        </form>
      </TableCell>
    </TableRow>
  )
}
