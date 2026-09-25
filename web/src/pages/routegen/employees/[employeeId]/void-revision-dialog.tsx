import { useState } from 'react'
import { toast } from 'sonner'
import type { SalaryHistoryEntry } from '@/api/types'
import { Alert, AlertDescription } from '@/components/ui/alert'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog'
import { Spinner } from '@/components/ui/spinner'
import { useMeta } from '@/data/app'
import { formatDate } from '@/lib/dates'
import { errorMessage } from '@/lib/errors'
import { formatMoney } from '@/lib/money'
import { voidRevision } from '@/pages/routegen/employees/data'

type VoidRevisionDialogProps = {
  employeeId: string
  revision: SalaryHistoryEntry | null
  onClose: () => void
}

export function VoidRevisionDialog({ employeeId, revision, onClose }: VoidRevisionDialogProps) {
  const meta = useMeta()
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<unknown>(null)

  function close() {
    setError(null)
    onClose()
  }

  async function confirm(id: string) {
    setSaving(true)
    try {
      await voidRevision(employeeId, id)
      toast.success('Revision voided')
      close()
    } catch (caught) {
      setError(caught)
    } finally {
      setSaving(false)
    }
  }

  return (
    <AlertDialog open={revision !== null} onOpenChange={(open) => !open && !saving && close()}>
      <AlertDialogContent>
        {revision && (
          <>
            <AlertDialogHeader>
              <AlertDialogTitle>Void this revision?</AlertDialogTitle>
              <AlertDialogDescription>
                {formatMoney(revision.amount_cents, meta)} from {formatDate(revision.effective_date)} drops out of the
                history and every salary figure. The change log keeps a record of it.
              </AlertDialogDescription>
            </AlertDialogHeader>
            {error !== null && (
              <Alert variant="destructive">
                <AlertDescription>{errorMessage(error)}</AlertDescription>
              </Alert>
            )}
            <AlertDialogFooter>
              <AlertDialogCancel disabled={saving}>Keep it</AlertDialogCancel>
              <AlertDialogAction
                variant="destructive"
                disabled={saving}
                onClick={(event) => {
                  // Stay open until the API answers, so a failure is not mistaken for success.
                  event.preventDefault()
                  void confirm(revision.id)
                }}
              >
                {saving && <Spinner />}
                Void revision
              </AlertDialogAction>
            </AlertDialogFooter>
          </>
        )}
      </AlertDialogContent>
    </AlertDialog>
  )
}
