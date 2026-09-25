import { fireEvent, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { history } from '@/test/fixtures'
import { renderApp } from '@/test/render'
import { apiError, server, url } from '@/test/server'

async function openAddRevision() {
  renderApp('/employees/employee-ada')
  await userEvent.click(await screen.findByRole('button', { name: 'Add revision' }))
  return screen.findByRole('dialog', { name: 'Add salary revision' })
}

describe('salary revision', () => {
  it('previews against the salary in force before the chosen date, and sends integer cents', async () => {
    let body: unknown
    server.use(
      http.post(url('/employees/:id/salary_revisions'), async ({ request }) => {
        body = await request.json()
        const change = { ...history[0], amount_cents: 13_200_050, effective_date: '2024-06-01' }
        return HttpResponse.json({ ...change, id: 'revision-3', previous_amount_cents: 10_000_000 }, { status: 201 })
      }),
    )
    const dialog = await openAddRevision()

    await userEvent.type(within(dialog).getByLabelText('Annual salary'), '132,000.50')
    expect(dialog).toHaveTextContent(/\$120,000.*\$132,000\.50.*\+10\.0%/)
    fireEvent.change(within(dialog).getByLabelText('Effective date'), { target: { value: '2024-06-01' } })
    expect(dialog).toHaveTextContent(/\$100,000.*\$132,000\.50.*\+32\.0%/)

    await userEvent.click(within(dialog).getByRole('button', { name: 'Save revision' }))
    await waitFor(() =>
      expect(body).toEqual({ amount_cents: 13_200_050, effective_date: '2024-06-01', reason: 'merit', note: null }),
    )
  })

  it('shows a 422 on an occupied date on the date field', async () => {
    server.use(
      http.post(url('/employees/:id/salary_revisions'), () =>
        apiError(422, 'validation_failed', 'Effective date has already been taken', [
          { field: 'effective_date', message: 'has already been taken' },
        ]),
      ),
    )
    const dialog = await openAddRevision()

    await userEvent.type(within(dialog).getByLabelText('Annual salary'), '132000')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Save revision' }))
    expect(await within(dialog).findByText('Has already been taken')).toBeInTheDocument()
    expect(within(dialog).getByLabelText('Effective date')).toHaveAttribute('aria-invalid', 'true')
  })
})
