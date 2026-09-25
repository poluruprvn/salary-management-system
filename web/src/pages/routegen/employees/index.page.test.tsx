import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { ada, meta, page } from '@/test/fixtures'
import { renderApp } from '@/test/render'
import { server, url } from '@/test/server'

describe('employee list', () => {
  it('sends the URL search as the request params, as of the server today', async () => {
    let params = new URLSearchParams()
    server.use(
      http.get(url('/employees'), ({ request }) => {
        params = new URL(request.url).searchParams
        return HttpResponse.json(page([ada]))
      }),
    )
    renderApp('/employees?department=%5B%22department-eng%22%5D&status=active&sort=-salary&page=2')

    await screen.findByText('Ada Lovelace')
    expect(params.getAll('department_id[]')).toEqual(['department-eng'])
    expect(params.get('status')).toBe('active')
    expect(params.get('sort')).toBe('-salary')
    expect(params.get('page')).toBe('2')
    expect(params.get('as_of')).toBe(meta.today)
  })

  it('sorting writes the URL and goes back to page 1', async () => {
    const router = renderApp('/employees?page=3')

    await userEvent.click(await screen.findByRole('button', { name: 'Salary' }))
    await waitFor(() => expect(router.state.location.href).toBe('/employees?sort=salary'))
  })

  it('filtering writes the URL and goes back to page 1', async () => {
    const router = renderApp('/employees?page=3')

    await userEvent.click(await screen.findByRole('radio', { name: 'Active' }))
    await waitFor(() => expect(router.state.location.href).toBe('/employees?status=active'))
  })

  it('search writes q after a pause, in place, without eating a space', async () => {
    const router = renderApp('/employees?page=3')
    const box = await screen.findByRole('searchbox')

    await userEvent.type(box, 'ada ')
    await waitFor(() => expect(router.state.location.href).toBe('/employees?q=ada'))
    await userEvent.type(box, 'love')
    await waitFor(() => expect(router.state.location.search).toEqual({ q: 'ada love' }))
    expect(router.history.length).toBe(1)
  })

  it('offers the last page past the end', async () => {
    server.use(http.get(url('/employees'), () => HttpResponse.json(page([], { total: 30, page: 9, total_pages: 2 }))))
    const router = renderApp('/employees?page=9')

    await userEvent.click(await screen.findByRole('button', { name: 'Go to the last page' }))
    await waitFor(() => expect(router.state.location.href).toBe('/employees?page=2'))
  })
})
