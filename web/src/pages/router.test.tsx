import { act, fireEvent, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { http, HttpResponse } from 'msw'
import { describe, expect, it } from 'vitest'
import { useSession } from '@/auth/session'
import { meta, tokens } from '@/test/fixtures'
import { renderApp } from '@/test/render'
import { apiError, server, url } from '@/test/server'

describe('app', () => {
  it('sends a signed-out visitor to sign in and back to the same list', async () => {
    const list = '/employees?department=%5B%22department-eng%22%5D&as_of=2026-06-30'
    const router = renderApp(list, { signedIn: false })

    await waitFor(() => expect(router.state.location.pathname).toBe('/sign-in'))
    act(() => useSession.getState().start(tokens('signed-in')))
    await waitFor(() => expect(router.state.location.href).toBe(list))
  })

  it('goes to sign in once when the session ends under a page', async () => {
    const router = renderApp('/employees')
    await screen.findByText('Ada Lovelace')

    act(() => useSession.getState().end())
    expect(await screen.findByRole('button', { name: 'Sign in' })).toBeInTheDocument()
    expect(router.state.location.href).toBe('/sign-in?redirect=%2Femployees')
  })

  it('shows the next manager to sign in their own name', async () => {
    renderApp('/employees')
    expect(await screen.findAllByText('HR Manager')).not.toHaveLength(0)

    act(() => useSession.getState().end())
    await screen.findByRole('button', { name: 'Sign in' })
    server.use(http.get(url('/me'), () => HttpResponse.json({ id: 'user-2', name: 'Grace Hopper', email: 'grace@example.com' })))
    act(() => useSession.getState().start(tokens('grace')))
    expect(await screen.findAllByText('Grace Hopper')).not.toHaveLength(0)
    expect(screen.queryByText('HR Manager')).not.toBeInTheDocument()
  })

  it('starts again from the error panel', async () => {
    let calls = 0
    server.use(http.get(url('/meta'), () => (++calls === 1 ? apiError(500, 'error', 'Boom') : HttpResponse.json(meta))))
    renderApp('/employees')

    await userEvent.click(await screen.findByRole('button', { name: 'Try again' }))
    expect(await screen.findByRole('heading', { name: 'Employees' })).toBeInTheDocument()
  })

  it('shows the date in use again when the as-of box is left empty', async () => {
    renderApp('/employees')
    const box = await screen.findByLabelText('As of')

    fireEvent.change(box, { target: { value: '' } })
    fireEvent.blur(box)
    expect(box).toHaveValue(meta.today)
  })
})
