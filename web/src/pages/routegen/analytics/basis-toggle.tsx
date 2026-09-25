import { ToggleGroup, ToggleGroupItem } from '@/components/ui/toggle-group'
import { BASIS_LABELS } from '@/pages/routegen/analytics/labels'
import { BASES, type Basis } from '@/pages/routegen/analytics/search'

export function BasisToggle({ value, onChange }: { value: Basis; onChange: (basis: Basis) => void }) {
  return (
    <ToggleGroup
      type="single"
      variant="outline"
      size="sm"
      spacing={0}
      value={value}
      onValueChange={(next) => next && onChange(next as Basis)}
      aria-label="Basis"
    >
      {BASES.map((basis) => (
        <ToggleGroupItem key={basis} value={basis}>
          {BASIS_LABELS[basis]}
        </ToggleGroupItem>
      ))}
    </ToggleGroup>
  )
}
