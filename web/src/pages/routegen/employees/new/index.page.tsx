import { zodResolver } from '@hookform/resolvers/zod'
import { Link, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import { Spinner } from '@/components/ui/spinner'
import { applyApiErrors } from '@/lib/errors'
import { BackToList } from '@/pages/routegen/employees/back-to-list'
import { createEmployee } from '@/pages/routegen/employees/data'
import { EmployeeForm } from '@/pages/routegen/employees/employee-form'
import { EMPLOYEE_FIELD_ALIASES, EMPTY_EMPLOYEE, employeeFormSchema } from '@/pages/routegen/employees/employee-schema'

export function NewEmployeePage() {
  const navigate = useNavigate()
  const form = useForm({ resolver: zodResolver(employeeFormSchema), defaultValues: EMPTY_EMPLOYEE })
  const [alert, setAlert] = useState<string | null>(null)

  const onSubmit = form.handleSubmit(async (values) => {
    setAlert(null)
    try {
      const employee = await createEmployee(values)
      toast.success(`${employee.name} added`, { description: 'Set their starting salary next.' })
      void navigate({ to: '/employees/$employeeId', params: { employeeId: employee.id } })
    } catch (error) {
      setAlert(applyApiErrors(error, form, EMPLOYEE_FIELD_ALIASES))
    }
  })

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-4">
      <BackToList />
      <div>
        <h1 className="font-heading text-xl font-semibold tracking-tight">New employee</h1>
        <p className="text-sm text-muted-foreground">Their salary is set on the next page, as the first revision.</p>
      </div>
      <Card>
        <CardContent>
          <EmployeeForm
            form={form}
            alert={alert}
            onSubmit={onSubmit}
            footer={
              <div className="flex justify-end gap-2">
                <Button variant="outline" asChild>
                  <Link to="/employees" disabled={form.formState.isSubmitting}>
                    Cancel
                  </Link>
                </Button>
                <Button type="submit" disabled={form.formState.isSubmitting}>
                  {form.formState.isSubmitting && <Spinner />}
                  Add employee
                </Button>
              </div>
            }
          />
        </CardContent>
      </Card>
    </div>
  )
}
