import { describe, expect, it, vi } from 'vitest'
import { ApiError, NetworkError } from '@/api/errors'
import { applyApiErrors } from '@/lib/errors'
import { EMPLOYEE_FIELD_ALIASES as aliases, EMPTY_EMPLOYEE } from '@/pages/routegen/employees/employee-schema'

function formWith(setError = vi.fn()) {
  return { setError, getValues: () => EMPTY_EMPLOYEE }
}

function invalid(details: { field: string; message: string }[], message = 'Validation failed') {
  return new ApiError(422, { error: { code: 'validation_failed', message, details } })
}

describe('applyApiErrors', () => {
  it('puts each detail on its field, including an association named for its column', () => {
    const setError = vi.fn()
    const left = applyApiErrors(
      invalid([
        { field: 'email', message: 'has already been taken' },
        { field: 'country', message: 'must exist' },
      ]),
      formWith(setError),
      aliases,
    )

    expect(left).toBeNull()
    expect(setError).toHaveBeenCalledWith('email', { message: 'Has already been taken' })
    expect(setError).toHaveBeenCalledWith('country_id', { message: 'Must exist' })
  })

  it('returns what has no field for an alert', () => {
    const setError = vi.fn()
    const left = applyApiErrors(
      invalid([
        { field: 'base', message: 'A voided revision cannot be edited' },
        { field: 'employee', message: 'must exist' },
      ]),
      formWith(setError),
      aliases,
    )

    expect(left).toBe('A voided revision cannot be edited. Employee must exist')
    expect(setError).not.toHaveBeenCalled()
  })

  it('falls back to the message when there are no details', () => {
    const left = applyApiErrors(invalid([], 'A record with these values already exists'), formWith(), aliases)

    expect(left).toBe('A record with these values already exists')
  })

  it('says when the API could not be reached', () => {
    expect(applyApiErrors(new NetworkError('Failed to fetch'), formWith(), aliases)).toMatch(/Could not reach the API/)
  })

  it('does not blame the network for a bug', () => {
    expect(applyApiErrors(new TypeError('Cannot read properties of undefined'), formWith(), aliases)).toBe(
      'Something went wrong.',
    )
  })
})
