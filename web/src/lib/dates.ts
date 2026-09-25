import { LOCALE } from '@/lib/locale'

const dateFormat = new Intl.DateTimeFormat(LOCALE, { dateStyle: 'medium', timeZone: 'UTC' })
const timestampFormat = new Intl.DateTimeFormat(LOCALE, { dateStyle: 'medium', timeStyle: 'short' })

// A date has no time zone. Read and printed as UTC, 2026-03-01 is Mar 1 everywhere, not Feb 28 west of Greenwich.
export function formatDate(date: string): string {
  const day = new Date(`${date}T00:00:00Z`)
  // A date input takes a year of five digits or more, which Date cannot read and format throws on.
  return Number.isNaN(day.getTime()) ? date : dateFormat.format(day)
}

export function formatTimestamp(timestamp: string): string {
  return timestampFormat.format(new Date(timestamp))
}
