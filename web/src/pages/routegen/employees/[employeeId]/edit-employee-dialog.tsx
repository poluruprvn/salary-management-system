import { zodResolver } from '@hookform/resolvers/zod'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { toast } from 'sonner'
import type { Employee } from '@/api/types'
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
import { Spinner } from '@/components/ui/spinner'
import { applyApiErrors } from '@/lib/errors'
import { pickDirty } from '@/lib/forms'
import { updateEmployee } from '@/pages/routegen/employees/data'
import { EmployeeForm } from '@/pages/routegen/employees/employee-form'
import { EMPLOYEE_FIELD_ALIASES, employeeFormSchema, employeeValues } from '@/pages/routegen/employees/employee-schema'

type EditEmployeeDialogProps = {
  employee: Employee
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function EditEmployeeDialog({ employee, open, onOpenChange }: EditEmployeeDialogProps) {
  // Open until the save answers, so a failure has somewhere to show.
  const [saving, setSaving] = useState(false)

  return (
    <Dialog open={open} onOpenChange={(next) => !saving && onOpenChange(next)}>
      <DialogContent className="sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>Edit {employee.name}</DialogTitle>
          <DialogDescription>Salary changes are revisions, on the salary history.</DialogDescription>
        </DialogHeader>
        {open && <EditEmployeeForm employee={employee} onSaving={setSaving} onDone={() => onOpenChange(false)} />}
      </DialogContent>
    </Dialog>
  )
}

type EditEmployeeFormProps = { employee: Employee; onSaving: (saving: boolean) => void; onDone: () => void }

function EditEmployeeForm({ employee, onSaving, onDone }: EditEmployeeFormProps) {
  const form = useForm({ resolver: zodResolver(employeeFormSchema), defaultValues: employeeValues(employee) })
  const [alert, setAlert] = useState<string | null>(null)

  const onSubmit = form.handleSubmit(async (values) => {
    setAlert(null)
    const patch = pickDirty(values, form.formState.dirtyFields)
    if (Object.keys(patch).length === 0) return onDone()

    onSaving(true)
    try {
      await updateEmployee(employee.id, patch)
      toast.success('Employee updated')
      onDone()
    } catch (error) {
      setAlert(applyApiErrors(error, form, EMPLOYEE_FIELD_ALIASES))
    } finally {
      onSaving(false)
    }
  })

  return (
    <EmployeeForm
      form={form}
      alert={alert}
      onSubmit={onSubmit}
      footer={
        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline" type="button" disabled={form.formState.isSubmitting}>
              Cancel
            </Button>
          </DialogClose>
          <Button type="submit" disabled={form.formState.isSubmitting}>
            {form.formState.isSubmitting && <Spinner />}
            Save changes
          </Button>
        </DialogFooter>
      }
    />
  )
}
