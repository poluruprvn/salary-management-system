import { describe, expect, it } from 'vitest'
import { formatDate } from '@/lib/dates'

describe('formatDate', () => {
  it('prints the calendar date it was given', () => {
    expect(formatDate('2026-03-01')).toBe('Mar 1, 2026')
    expect(formatDate('2024-02-29')).toBe('Feb 29, 2024')
  })

  it('prints a date it cannot read as it came, rather than throwing', () => {
    expect(formatDate('20266-01-15')).toBe('20266-01-15')
  })
})
