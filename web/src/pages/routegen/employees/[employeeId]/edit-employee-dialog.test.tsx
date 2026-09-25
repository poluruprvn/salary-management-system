import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { ada } from '@/test/fixtures'
import { renderApp } from '@/test/render'
import { apiError, server, url } from '@/test/server'

async function openEdit() {
  renderApp('/employees/employee-ada')
  await userEvent.click(await screen.findByRole('button', { name: 'Edit' }))
  return screen.findByRole('dialog', { name: 'Edit Ada Lovelace' })
}

describe('edit employee', () => {
  it('sends only the fields that changed, and null for a cleared exit date', async () => {
    let patch: unknown
    server.use(
      http.get(url('/employees/:id'), () => HttpResponse.json({ ...ada, exit_date: '2026-12-31' })),
      http.patch(url('/employees/:id'), async ({ request }) => {
        patch = await request.json()
        return HttpResponse.json(ada)
      }),
    )
    const dialog = await openEdit()

    await userEvent.type(within(dialog).getByLabelText('Name'), ' King')
    fireEvent.change(within(dialog).getByLabelText('Exit date'), { target: { value: '' } })
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save changes' }))
    await waitFor(() => expect(patch).toEqual({ name: 'Ada Lovelace King', exit_date: null }))
  })

  it('puts each 422 detail on its field, and country on the country select', async () => {
    server.use(
      http.patch(url('/employees/:id'), () =>
        apiError(422, 'validation_failed', 'Validation failed', [
          { field: 'email', message: 'has already been taken' },
          { field: 'country', message: 'must exist' },
        ]),
      ),
    )
    const dialog = await openEdit()

    await userEvent.type(within(dialog).getByLabelText('Name'), ' King')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save changes' }))
    expect(await within(dialog).findByText('Has already been taken')).toBeInTheDocument()
    expect(within(dialog).getByLabelText('Email')).toHaveAttribute('aria-invalid', 'true')
    expect(within(dialog).getByText('Must exist')).toBeInTheDocument()
    expect(within(dialog).getByRole('combobox', { name: 'Country' })).toHaveAttribute('aria-invalid', 'true')
  })
})
