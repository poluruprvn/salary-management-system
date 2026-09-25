import { screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { countries } from '@/test/fixtures'
import { renderApp } from '@/test/render'
import { apiError, server, url } from '@/test/server'

describe('countries', () => {
  it('puts a 422 on the row it belongs to', async () => {
    server.use(
      http.patch(url('/countries/country-us'), () =>
        apiError(422, 'validation_failed', 'Validation failed', [
          { field: 'employer_cost_multiplier', message: 'must be less than 100' },
        ]),
      ),
    )
    renderApp('/settings/countries')

    const input = await screen.findByLabelText('United States')
    await userEvent.clear(input)
    await userEvent.type(input, '99.5')
    const row = input.closest('tr') as HTMLElement
    await userEvent.click(within(row).getByRole('button', { name: 'Save' }))

    expect(await within(row).findByText('Must be less than 100')).toBeInTheDocument()
    const india = screen.getByLabelText('India').closest('tr') as HTMLElement
    expect(within(india).queryByRole('alert')).not.toBeInTheDocument()
  })

  it('refuses a fifth decimal place without a request', async () => {
    renderApp('/settings/countries')

    const input = await screen.findByLabelText('India')
    await userEvent.clear(input)
    await userEvent.type(input, '1.45678')
    await userEvent.click(within(input.closest('tr') as HTMLElement).getByRole('button', { name: 'Save' }))

    expect(await screen.findByText(/at most 4 decimal places/)).toBeInTheDocument()
  })

  it('sends the multiplier as a string and reloads the countries', async () => {
    let body: unknown
    const saved = { ...countries[0], employer_cost_multiplier: '1.2' }
    let current = countries
    server.use(
      http.patch(url('/countries/country-in'), async ({ request }) => {
        body = await request.json()
        current = [saved, countries[1]]
        return HttpResponse.json(saved)
      }),
      http.get(url('/countries'), () => HttpResponse.json({ data: current })),
    )
    renderApp('/settings/countries')

    const input = await screen.findByLabelText('India')
    await userEvent.clear(input)
    await userEvent.type(input, '1.2')
    await userEvent.click(within(input.closest('tr') as HTMLElement).getByRole('button', { name: 'Save' }))

    await waitFor(() => expect(body).toEqual({ employer_cost_multiplier: '1.2' }))
    const row = () => screen.getByLabelText('India').closest('tr') as HTMLElement
    await waitFor(() => expect(within(row()).getByRole('button', { name: 'Save' })).toBeDisabled())
    expect(screen.getByLabelText('India')).toHaveValue('1.2')
  })

  it('refuses zero and a malformed number without a request', async () => {
    renderApp('/settings/countries')

    const input = await screen.findByLabelText('India')
    const save = within(input.closest('tr') as HTMLElement).getByRole('button', { name: 'Save' })
    await userEvent.clear(input)
    await userEvent.type(input, '0')
    await userEvent.click(save)
    expect(await screen.findByText('Must be above 0')).toBeInTheDocument()

    await userEvent.clear(input)
    await userEvent.type(input, '1.')
    await userEvent.click(save)
    expect(await screen.findByText(/at most 4 decimal places/)).toBeInTheDocument()
  })

  it('shows an error the form has no field for', async () => {
    server.use(http.patch(url('/countries/country-in'), () => apiError(404, 'not_found', 'Country not found')))
    renderApp('/settings/countries')

    const input = await screen.findByLabelText('India')
    await userEvent.clear(input)
    await userEvent.type(input, '1.2')
    await userEvent.click(within(input.closest('tr') as HTMLElement).getByRole('button', { name: 'Save' }))

    expect(await screen.findByRole('alert')).toBeInTheDocument()
  })
})
