import createClient from 'openapi-fetch'
import { ApiError } from '@/api/errors'
import type { paths } from '@/api/schema'
import { API_URL, authorizedFetch } from '@/api/transport'

export const api = createClient<paths>({ baseUrl: API_URL, fetch: authorizedFetch })

export async function unwrap<T>(request: Promise<{ data?: T; error?: unknown; response: Response }>): Promise<T> {
  const { data, error, response } = await request
  if (!response.ok) throw new ApiError(response.status, error)

  return data as T
}
