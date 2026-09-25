import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { distributionRow, meta, page } from '@/test/fixtures'
import { renderApp } from '@/test/render'
import { server, url } from '@/test/server'

describe('distribution', () => {
  it('sends the URL search as the request params', async () => {
    let params = new URLSearchParams()
    server.use(
      http.get(url('/analytics/distribution'), ({ request }) => {
        params = new URL(request.url).searchParams
        return HttpResponse.json({ as_of: meta.today, group_by: 'level', unsalaried: 2, ...page([distributionRow]) })
      }),
    )
    renderApp('/analytics/distribution?group_by=level&department=%5B%22department-eng%22%5D&sort=-median&page=2')

    await screen.findByText('$110,000')
    expect(params.get('group_by')).toBe('level')
    expect(params.getAll('department_id[]')).toEqual(['department-eng'])
    expect(params.get('sort')).toBe('-median')
    expect(params.get('page')).toBe('2')
    expect(params.get('as_of')).toBe(meta.today)
    expect(screen.getByText(/2 active employees matched but have no salary/)).toBeInTheDocument()
  })

  it('changing the grouping drops the sort and the page', async () => {
    const router = renderApp('/analytics/distribution?group_by=level&sort=-median&page=2')

    await userEvent.click(await screen.findByRole('radio', { name: 'Title' }))
    await waitFor(() => expect(router.state.location.href).toBe('/analytics/distribution?group_by=title'))
  })

  it('offers the last page when the page is past the end', async () => {
    server.use(
      http.get(url('/analytics/distribution'), () =>
        HttpResponse.json({
          as_of: meta.today,
          group_by: 'department',
          unsalaried: 0,
          ...page([], { total: 30, page: 3, total_pages: 2 }),
        }),
      ),
    )
    const router = renderApp('/analytics/distribution?page=3')

    await userEvent.click(await screen.findByRole('button', { name: 'Go to the last page' }))
    await waitFor(() => expect(router.state.location.href).toBe('/analytics/distribution?page=2'))
  })
})
