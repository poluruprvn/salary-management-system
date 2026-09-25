import { z } from 'zod'
import type { Employee } from '@/api/types'

const text = (message: string) => z.string().trim().min(1, message).max(255, 'Keep it under 256 characters')

export const employeeFormSchema = z
  .object({
    name: text('Enter a name'),
    email: text('Enter an email address').pipe(z.email('Enter a valid email address')),
    title: text('Enter a title'),
    department_id: z.string().min(1, 'Choose a department'),
    country_id: z.string().min(1, 'Choose a country'),
    level_id: z.string().min(1, 'Choose a level'),
    hire_date: z.iso.date('Enter the hire date'),
    exit_date: z
      .union([z.literal(''), z.iso.date()], 'Enter a date, or leave it empty')
      .transform((date) => date || null),
  })
  .refine((values) => !values.exit_date || values.exit_date >= values.hire_date, {
    path: ['exit_date'],
    message: 'Must be on or after the hire date',
  })

export type EmployeeFormValues = z.input<typeof employeeFormSchema>
export type EmployeeFormOutput = z.output<typeof employeeFormSchema>

export const EMPTY_EMPLOYEE: EmployeeFormValues = {
  name: '',
  email: '',
  title: '',
  department_id: '',
  country_id: '',
  level_id: '',
  hire_date: '',
  exit_date: '',
}

export function employeeValues(employee: Employee): EmployeeFormValues {
  return {
    name: employee.name,
    email: employee.email,
    title: employee.title,
    department_id: employee.department.id,
    country_id: employee.country.id,
    level_id: employee.level.id,
    hire_date: employee.hire_date,
    exit_date: employee.exit_date ?? '',
  }
}

// Rails names a belongs_to error after the association, not the column the form sends.
export const EMPLOYEE_FIELD_ALIASES = {
  department: 'department_id',
  country: 'country_id',
  level: 'level_id',
} as const
