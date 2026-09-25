import type { DistributionGroupBy } from '@/api/types'
import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { GROUP_LABELS } from '@/pages/routegen/analytics/labels'

type GroupToggleProps<G extends DistributionGroupBy> = {
  groups: readonly G[]
  value: G
  onChange: (group: G) => void
}

export function GroupToggle<G extends DistributionGroupBy>({ groups, value, onChange }: GroupToggleProps<G>) {
  return (
    <ToggleGroup
      type="single"
      variant="outline"
      size="sm"
      spacing={0}
      value={value}
      onValueChange={(next) => next && onChange(next as G)}
      aria-label="Group by"
    >
      {groups.map((group) => (
        <ToggleGroupItem key={group} value={group}>
          {GROUP_LABELS[group]}
        </ToggleGroupItem>
      ))}
    </ToggleGroup>
  )
}
