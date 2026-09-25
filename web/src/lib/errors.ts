import { ApiError, NetworkError } from '@/api/errors'

export function errorMessage(error: unknown): string {
  if (error instanceof ApiError) return error.message
  if (error instanceof NetworkError) return 'Could not reach the API. Check that it is running and try again.'

  return 'Something went wrong.'
}

// Method syntax so a form typed for its own field names still fits.
type ErrorForm = { setError(name: string, error: { message: string }): void; getValues(): object }

// Puts each 422 detail on the form field it names. aliases maps API names that differ from the form's.
// Returns what is left for an alert above the form, or null when every detail found its field.
export function applyApiErrors(error: unknown, form: ErrorForm, aliases: Record<string, string> = {}): string | null {
  if (!(error instanceof ApiError) || error.details.length === 0) return errorMessage(error)

  const fields = Object.keys(form.getValues())
  const unplaced: string[] = []
  for (const detail of error.details) {
    const field = aliases[detail.field] ?? (fields.includes(detail.field) ? detail.field : undefined)
    if (field) {
      form.setError(field, { message: capitalize(detail.message) })
    } else {
      unplaced.push(detail.field === 'base' ? detail.message : `${humanize(detail.field)} ${detail.message}`)
    }
  }

  return unplaced.length > 0 ? unplaced.join('. ') : null
}

function capitalize(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1)
}

function humanize(field: string): string {
  return capitalize(field.replaceAll('_', ' '))
}
