import { create } from 'zustand'

export const useWriteCount = create(() => 0)

// Every useApi loads again after a write. A backdated revision changes the previous amount of the one after it,
// the list's salary column and the change log, so reloading one view is not enough.
export async function write<T>(request: () => Promise<T>): Promise<T> {
  const result = await request()
  useWriteCount.setState((count) => count + 1, true)
  return result
}
