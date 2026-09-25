// Only what changed, so a stale value cannot overwrite someone else's edit.
export function pickDirty<T extends object>(values: T, dirty: Record<string, unknown>): Partial<T> {
  return Object.fromEntries(Object.entries(values).filter(([key]) => dirty[key])) as Partial<T>
}
