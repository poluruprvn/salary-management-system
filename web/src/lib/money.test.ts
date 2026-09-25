import { describe, expect, it } from 'vitest'
import { formatChange, formatMoney, parseMoney } from '@/lib/money'

const usd = { base_currency: 'USD', minor_unit: 2 }

describe('parseMoney', () => {
  it('reads whole amounts, grouping and decimals as cents', () => {
    expect(parseMoney('132000', usd)).toBe(13_200_000)
    expect(parseMoney('132,000', usd)).toBe(13_200_000)
    expect(parseMoney(' 132 000.5 ', usd)).toBe(13_200_050)
    expect(parseMoney('120.', usd)).toBe(12_000)
  })

  it('is exact where float arithmetic is not', () => {
    expect(parseMoney('0.29', usd)).toBe(29)
    expect(parseMoney('1.15', usd)).toBe(115)
    expect(parseMoney('4.35', usd)).toBe(435)
  })

  it('refuses more decimals than the currency has, and anything that is not an amount', () => {
    expect(parseMoney('1.005', usd)).toBeNull()
    expect(parseMoney('', usd)).toBeNull()
    expect(parseMoney('-5', usd)).toBeNull()
    expect(parseMoney('12abc', usd)).toBeNull()
    expect(parseMoney('$120', usd)).toBeNull()
  })
})

describe('formatMoney', () => {
  it('drops the cents only when there are none', () => {
    expect(formatMoney(13_200_000, usd)).toBe('$132,000')
    expect(formatMoney(13_200_050, usd)).toBe('$132,000.50')
  })

  it('signs a change', () => {
    expect(formatMoney(1_200_000, usd, { signed: true })).toBe('+$12,000')
    expect(formatMoney(-50_000, usd, { signed: true })).toBe('-$500')
    expect(formatMoney(0, usd, { signed: true })).toBe('$0')
  })
})

describe('formatChange', () => {
  it('is a signed percent to one decimal', () => {
    expect(formatChange(13_200_000, 12_000_000)).toBe('+10.0%')
    expect(formatChange(11_400_000, 12_000_000)).toBe('-5.0%')
    expect(formatChange(12_000_000, 12_000_000)).toBe('0.0%')
  })
})
