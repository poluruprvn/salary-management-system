import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterAll, afterEach, beforeAll } from 'vitest'
import { useSession } from '@/auth/session'
import { clearListSearchOnSignOut } from '@/pages/routegen/employees/list-store'
import { server } from '@/test/server'

// jsdom lacks these. Radix and cmdk call the first five, and sonner calls matchMedia.
globalThis.ResizeObserver ??= class {
  observe() {}
  unobserve() {}
  disconnect() {}
}
Element.prototype.hasPointerCapture ??= () => false
Element.prototype.setPointerCapture ??= () => {}
Element.prototype.releasePointerCapture ??= () => {}
Element.prototype.scrollIntoView ??= () => {}
window.matchMedia ??= (query: string) =>
  ({
    matches: false,
    media: query,
    onchange: null,
    addEventListener: () => {},
    removeEventListener: () => {},
    addListener: () => {},
    removeListener: () => {},
    dispatchEvent: () => false,
  }) as MediaQueryList
// jsdom only logs that scrollTo is not implemented. The router's scroll restoration calls it.
window.scrollTo = () => {}

clearListSearchOnSignOut()

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))

afterEach(() => {
  cleanup()
  server.resetHandlers()
  useSession.getState().end()
  localStorage.clear()
})

afterAll(() => server.close())
