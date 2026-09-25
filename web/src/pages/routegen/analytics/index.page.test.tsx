import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { meta, runRate } from '@/test/fixtures'
import { renderApp } from '@/test/render'
import { apiError, server, url } from '@/test/server'

const departmentOrder = () =>
  screen.getAllByRole('link', { name: /^(Engineering|Sales)$/ }).map((link) => link.textContent)

describe('analytics overview', () => {
  it('sends the URL search as the request params, as of the server today', async () => {
    let params = new URLSearchParams()
    server.use(
      http.get(url('/analytics/run_rate'), ({ request }) => {
        params = new URL(request.url).searchParams
        return HttpResponse.json(runRate('level'))
      }),
    )
    renderApp('/analytics?group_by=level')

    expect(await screen.findByRole('link', { name: 'L4' })).toBeInTheDocument()
    expect(params.get('group_by')).toBe('level')
    expect(params.get('as_of')).toBe(meta.today)
  })

  it('switches basis without a request, and re-sorts the rows by it', async () => {
    let requests = 0
    server.use(
      http.get(url('/analytics/run_rate'), () => {
        requests += 1
        return HttpResponse.json(runRate())
      }),
    )
    const router = renderApp('/analytics')

    await screen.findByText('$605,000')
    expect(departmentOrder()).toEqual(['Sales', 'Engineering'])
    await userEvent.click(screen.getByRole('radio', { name: 'Gross' }))
    await waitFor(() => expect(router.state.location.href).toBe('/analytics?basis=gross'))
    expect(await screen.findByText('$500,000')).toBeInTheDocument()
    expect(departmentOrder()).toEqual(['Engineering', 'Sales'])
    expect(requests).toBe(1)
  })

  it('switches the grouping', async () => {
    renderApp('/analytics')

    await screen.findByRole('link', { name: 'Engineering' })
    await userEvent.click(screen.getByRole('radio', { name: 'Level' }))
    expect(await screen.findByRole('link', { name: 'L3' })).toHaveAttribute(
      'href',
      '/employees?level=%5B%22level-3%22%5D&status=active',
    )
  })

  it('shows an error when a reload fails, not the previous figures', async () => {
    renderApp('/analytics')

    await screen.findByRole('link', { name: 'Engineering' })
    server.use(http.get(url('/analytics/run_rate'), () => apiError(500, 'internal_error', 'Something broke')))
    await userEvent.click(screen.getByRole('radio', { name: 'Level' }))
    expect(await screen.findByText('Could not load the run rate')).toBeInTheDocument()
    expect(screen.queryByText('$605,000')).not.toBeInTheDocument()
  })

  it('shows the active employees with no salary on file', async () => {
    renderApp('/analytics')

    expect(await screen.findByText('1 active employee')).toBeInTheDocument()
  })
})
