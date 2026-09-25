import { getRouteApi } from '@tanstack/react-router'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { formatDate } from '@/lib/dates'
import { useAsOf } from '@/data/app'
import { AnalyticsHeader } from '@/pages/routegen/analytics/analytics-header'
import { CohortGrid } from '@/pages/routegen/analytics/outliers/cohort-grid'
import { OutlierList } from '@/pages/routegen/analytics/outliers/outlier-list'
import type { OutliersSearch } from '@/pages/routegen/analytics/search'

const route = getRouteApi('/app/analytics/outliers')

export function OutliersPage() {
  const { as_of: _, ...search } = route.useSearch()
  const navigate = route.useNavigate()
  const { asOf } = useAsOf()

  const update = (changes: Partial<OutliersSearch>) =>
    void navigate({ search: (prev) => ({ ...prev, page: undefined, ...changes }) })

  return (
    <div className="flex flex-col gap-4">
      <AnalyticsHeader
        description={`Salaries outside 1.5 times the interquartile range of their level and country, as of ${formatDate(asOf)}`}
      />
      <Tabs
        value={search.tab}
        onValueChange={(value) =>
          void navigate({ search: (prev) => ({ ...prev, tab: value as OutliersSearch['tab'] }), replace: true })
        }
      >
        <TabsList variant="line">
          <TabsTrigger value="people">People</TabsTrigger>
          <TabsTrigger value="cohorts">Cohorts</TabsTrigger>
        </TabsList>
        <TabsContent value="people" className="pt-2">
          <OutlierList search={search} update={update} />
        </TabsContent>
        <TabsContent value="cohorts" className="pt-2">
          <CohortGrid
            onOpen={(level, country) =>
              update({ tab: 'people', level: [level], country: [country], department: undefined, direction: undefined })
            }
          />
        </TabsContent>
      </Tabs>
    </div>
  )
}
