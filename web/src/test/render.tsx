import { createMemoryHistory, RouterProvider } from '@tanstack/react-router'
import { render } from '@testing-library/react'
import { useSession } from '@/auth/session'
import { TooltipProvider } from '@/components/ui/tooltip'
import { createAppRouter } from '@/pages/router'

export function renderApp(path: string, { signedIn = true } = {}) {
  if (signedIn) useSession.setState({ refreshToken: 'refresh-stored' })
  const router = createAppRouter(createMemoryHistory({ initialEntries: [path] }))
  render(
    <TooltipProvider>
      <RouterProvider router={router} />
    </TooltipProvider>,
  )

  return router
}
