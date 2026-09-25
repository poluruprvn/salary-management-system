import type { ReactNode, Ref } from 'react'
import { type Control, Controller, type ControllerRenderProps, type FieldPath, type FieldValues } from 'react-hook-form'
import { Field, FieldDescription, FieldError, FieldLabel } from '@/components/ui/field'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'

type InputProps<T extends FieldValues> = ControllerRenderProps<T> & {
  id: string
  'aria-invalid': boolean
}

type FormFieldProps<T extends FieldValues, TOutput> = {
  control: Control<T, unknown, TOutput>
  name: FieldPath<T>
  label: string
  description?: string
  children: (input: InputProps<T>) => ReactNode
}

export function FormField<T extends FieldValues, TOutput>({
  control,
  name,
  label,
  description,
  children,
}: FormFieldProps<T, TOutput>) {
  return (
    <Controller
      control={control}
      name={name}
      render={({ field, fieldState }) => (
        <Field data-invalid={fieldState.invalid}>
          <FieldLabel htmlFor={name}>{label}</FieldLabel>
          {children({ ...field, id: name, 'aria-invalid': fieldState.invalid })}
          {description && <FieldDescription>{description}</FieldDescription>}
          <FieldError errors={[fieldState.error]} />
        </Field>
      )}
    />
  )
}

type SelectInputProps = {
  id: string
  name: string
  value: string
  onChange: (value: string) => void
  onBlur: () => void
  ref?: Ref<HTMLButtonElement>
  'aria-invalid': boolean
  options: { value: string; label: string }[]
  placeholder?: string
}

export function SelectInput({
  id,
  name,
  value,
  onChange,
  onBlur,
  ref,
  'aria-invalid': invalid,
  options,
  placeholder,
}: SelectInputProps) {
  return (
    <Select name={name} value={value} onValueChange={onChange}>
      <SelectTrigger ref={ref} id={id} className="w-full" aria-invalid={invalid} onBlur={onBlur}>
        <SelectValue placeholder={placeholder} />
      </SelectTrigger>
      <SelectContent>
        {options.map((option) => (
          <SelectItem key={option.value} value={option.value}>
            {option.label}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}
