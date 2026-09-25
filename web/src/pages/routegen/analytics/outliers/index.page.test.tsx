import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { meta, outlier, page } from '@/test/fixtures'
import { renderApp } from '@/test/render'
import { server, url } from '@/test/server'

describe('outliers', () => {
  it('sends the URL search as the request params', async () => {
    let params = new URLSearchParams()
    server.use(
      http.get(url('/analytics/outliers'), ({ request }) => {
        params = new URL(request.url).searchParams
        return HttpResponse.json({ as_of: meta.today, ...page([outlier]) })
      }),
    )
    renderApp('/analytics/outliers?country=%5B%22country-in%22%5D&direction=above&page=2')

    await screen.findByText('+63.6%')
    expect(params.getAll('country_id[]')).toEqual(['country-in'])
    expect(params.get('direction')).toBe('above')
    expect(params.get('page')).toBe('2')
    expect(params.get('as_of')).toBe(meta.today)
  })

  it('opens a cohort as a filtered list of people, whatever the earlier filters', async () => {
    const router = renderApp('/analytics/outliers?tab=cohorts&department=%5B%22department-eng%22%5D&direction=below')

    expect(await screen.findByText('Not evaluated, fewer than 5 people')).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: /1 outside/ }))
    await waitFor(() =>
      expect(router.state.location.href).toBe(
        '/analytics/outliers?level=%5B%22level-3%22%5D&country=%5B%22country-in%22%5D',
      ),
    )
  })

  it('switches direction and drops the page', async () => {
    const router = renderApp('/analytics/outliers?direction=above&page=2')

    await screen.findByText('+63.6%')
    await userEvent.click(screen.getByRole('radio', { name: 'Both' }))
    await waitFor(() => expect(router.state.location.href).toBe('/analytics/outliers'))
    await userEvent.click(screen.getByRole('radio', { name: 'Below' }))
    await waitFor(() => expect(router.state.location.href).toBe('/analytics/outliers?direction=below'))
  })

  it('offers the last page when the page is past the end', async () => {
    server.use(
      http.get(url('/analytics/outliers'), () =>
        HttpResponse.json({ as_of: meta.today, ...page([], { total: 3, page: 4, total_pages: 1 }) }),
      ),
    )
    const router = renderApp('/analytics/outliers?page=4')

    await userEvent.click(await screen.findByRole('button', { name: 'Go to the last page' }))
    await waitFor(() => expect(router.state.location.href).toBe('/analytics/outliers'))
  })
})
