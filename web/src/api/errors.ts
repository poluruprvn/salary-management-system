import type { ErrorBody } from '@/api/types'

export class ApiError extends Error {
  readonly status: number
  readonly code: string
  readonly details: ErrorBody['error']['details']

  constructor(status: number, body: unknown) {
    const error = isErrorBody(body) ? body.error : undefined
    super(error?.message ?? `The API answered ${status}`)
    this.name = 'ApiError'
    this.status = status
    this.code = error?.code ?? 'unknown'
    this.details = error?.details ?? []
  }
}

export class NetworkError extends Error {}

export function isErrorBody(body: unknown): body is ErrorBody {
  return typeof body === 'object' && body !== null && 'error' in body
}
