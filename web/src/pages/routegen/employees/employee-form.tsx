import type { ReactNode } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { FormField, SelectInput } from '@/components/form-field'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { FieldGroup } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { useClosedSets } from '@/data/app'
import type { EmployeeFormOutput, EmployeeFormValues } from '@/pages/routegen/employees/employee-schema'
import { levelLabel } from '@/pages/routegen/employees/labels'
import { TitleInput } from '@/pages/routegen/employees/title-input'

type EmployeeFormProps = {
  form: UseFormReturn<EmployeeFormValues, unknown, EmployeeFormOutput>
  alert: string | null
  onSubmit: () => void
  footer: ReactNode
}

export function EmployeeForm({ form, alert, onSubmit, footer }: EmployeeFormProps) {
  const { departments, countries, levels } = useClosedSets()
  const { control } = form

  return (
    <form onSubmit={onSubmit} noValidate className="grid gap-6">
      <FieldGroup className="gap-4">
        {alert && (
          <Alert variant="destructive">
            <AlertDescription>{alert}</AlertDescription>
          </Alert>
        )}
        <div className="grid gap-4 sm:grid-cols-2">
          <FormField control={control} name="name" label="Name">
            {(input) => <Input {...input} autoComplete="off" />}
          </FormField>
          <FormField control={control} name="email" label="Email">
            {(input) => <Input {...input} type="email" autoComplete="off" />}
          </FormField>
        </div>
        <FormField
          control={control}
          name="title"
          label="Title"
          description="Pick a title already in use where one fits, so pay by title stays comparable."
        >
          {(input) => <TitleInput {...input} />}
        </FormField>
        <div className="grid gap-4 sm:grid-cols-3">
          <FormField control={control} name="department_id" label="Department">
            {(input) => (
              <SelectInput
                {...input}
                placeholder="Choose"
                options={departments.map((department) => ({ value: department.id, label: department.name }))}
              />
            )}
          </FormField>
          <FormField control={control} name="country_id" label="Country">
            {(input) => (
              <SelectInput
                {...input}
                placeholder="Choose"
                options={countries.map((country) => ({ value: country.id, label: country.name }))}
              />
            )}
          </FormField>
          <FormField control={control} name="level_id" label="Level">
            {(input) => (
              <SelectInput
                {...input}
                placeholder="Choose"
                options={levels.map((level) => ({ value: level.id, label: levelLabel(level) }))}
              />
            )}
          </FormField>
        </div>
        <div className="grid gap-4 sm:grid-cols-2">
          <FormField control={control} name="hire_date" label="Hire date">
            {(input) => <Input {...input} type="date" />}
          </FormField>
          <FormField
            control={control}
            name="exit_date"
            label="Exit date"
            description="Optional. The last day worked and paid."
          >
            {(input) => <Input {...input} type="date" />}
          </FormField>
        </div>
      </FieldGroup>
      {footer}
    </form>
  )
}
