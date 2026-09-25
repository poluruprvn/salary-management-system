import { api, unwrap } from '@/api/client'
import { write } from '@/hooks/writes'

export function updateMultiplier(id: string, multiplier: string) {
  return write(() =>
    unwrap(api.PATCH('/api/v1/countries/{id}', { params: { path: { id } }, body: { employer_cost_multiplier: multiplier } })),
  )
}
