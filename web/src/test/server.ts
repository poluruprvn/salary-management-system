import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { API_URL } from '@/api/transport'
import * as fixtures from '@/test/fixtures'

export const url = (path: string) => `${API_URL}/api/v1${path}`

export const server = setupServer(
  http.post(url('/auth/refresh'), () => HttpResponse.json(fixtures.tokens('refreshed'))),
  http.get(url('/meta'), () => HttpResponse.json(fixtures.meta)),
  http.get(url('/me'), () => HttpResponse.json(fixtures.user)),
  http.get(url('/countries'), () => HttpResponse.json({ data: fixtures.countries })),
  http.get(url('/departments'), () => HttpResponse.json({ data: fixtures.departments })),
  http.get(url('/levels'), () => HttpResponse.json({ data: fixtures.levels })),
  http.get(url('/titles'), () => HttpResponse.json({ data: fixtures.titles })),
  http.get(url('/employees'), () => HttpResponse.json(fixtures.page([fixtures.ada]))),
  http.get(url('/employees/:id'), () => HttpResponse.json(fixtures.ada)),
  http.get(url('/employees/:id/salary_revisions'), () => HttpResponse.json({ data: fixtures.history })),
  http.get(url('/employees/:id/audits'), () => HttpResponse.json(fixtures.page(fixtures.audits))),
)

export function apiError(status: number, code: string, message: string, details: { field: string; message: string }[] = []) {
  return HttpResponse.json({ error: { code, message, details } }, { status })
}
