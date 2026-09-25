import type { Meta } from '@/api/types'
import { LOCALE } from '@/lib/locale'

export type Currency = Pick<Meta, 'base_currency' | 'minor_unit'>

// Display only. Any amount the API accepts divides to a double that still rounds to the exact cent.
export function formatMoney(cents: number, currency: Currency, { signed = false } = {}): string {
  return new Intl.NumberFormat(LOCALE, {
    style: 'currency',
    currency: currency.base_currency,
    trailingZeroDisplay: 'stripIfInteger',
    signDisplay: signed ? 'exceptZero' : 'auto',
  }).format(cents / 10 ** currency.minor_unit)
}

// For an input: grouped, no symbol, and cents only when there are some. parseMoney reads it back.
export function formatAmount(cents: number, currency: Currency): string {
  return new Intl.NumberFormat(LOCALE, {
    minimumFractionDigits: currency.minor_unit,
    trailingZeroDisplay: 'stripIfInteger',
  }).format(cents / 10 ** currency.minor_unit)
}

// Grouping commas and spaces are dropped. More decimals than the currency has are refused, not rounded.
export function parseMoney(text: string, currency: Currency): number | null {
  const match = /^(\d+)(?:\.(\d*))?$/.exec(text.replace(/[\s,]/g, ''))
  if (!match) return null

  const [, whole, fraction = ''] = match
  if (fraction.length > currency.minor_unit) return null

  return Number(whole) * 10 ** currency.minor_unit + Number(fraction.padEnd(currency.minor_unit, '0') || '0')
}

const percent = new Intl.NumberFormat(LOCALE, {
  style: 'percent',
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
  signDisplay: 'exceptZero',
})

export function formatChange(amount: number, previous: number): string {
  return percent.format((amount - previous) / previous)
}

// For a chart axis, where $1.2M reads faster than $1,234,567.
export function formatCompactMoney(cents: number, currency: Currency): string {
  return new Intl.NumberFormat(LOCALE, {
    style: 'currency',
    currency: currency.base_currency,
    notation: 'compact',
    maximumFractionDigits: 1,
  }).format(cents / 10 ** currency.minor_unit)
}

const signedPercent = new Intl.NumberFormat(LOCALE, {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
  signDisplay: 'exceptZero',
})

// For a percent the API already computed, like 12.5 for 12.5%.
export function formatPercent(value: number): string {
  return `${signedPercent.format(value)}%`
}
