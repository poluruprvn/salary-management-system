module Analytics
  class Outliers
    DISTANCE = "(salaried.amount_cents - cohort_stats.p50) / cohort_stats.p50 * 100"
    private_constant :DISTANCE

    # The filters narrow who is listed, never the cohort. The fence belongs to the whole level and
    # country, so the same person is an outlier on every screen or on none.
    def self.call(as_of:, filters: {}, direction: nil)
      fences = CohortStats::OUTSIDE_FENCE
      outside =
        if direction.blank?
          fences.values.join(" OR ")
        else
          fences.fetch(direction.to_s) { raise InvalidParameter.new(:direction, "must be one of #{fences.keys.join(", ")}") }
        end

      CohortStats.with(Employees::List.filter(filters, as_of: as_of), as_of)
        .joins("JOIN salaried ON salaried.id = employees.id")
        .joins("JOIN cohort_stats ON cohort_stats.level_id = employees.level_id AND cohort_stats.country_id = employees.country_id")
        .joins(:department, :level, :country)
        .where(outside)
        .select("employees.id", "employees.name",
                "departments.id AS department_id", "departments.name AS department_name",
                "levels.id AS level_id", "levels.name AS level_name",
                "countries.id AS country_id", "countries.name AS country_name",
                "salaried.amount_cents",
                "ROUND(cohort_stats.p50::numeric)::bigint AS cohort_median_cents",
                "cohort_stats.headcount AS cohort_headcount",
                "CASE WHEN #{fences["below"]} THEN 'below' ELSE 'above' END AS direction",
                "ROUND((#{DISTANCE})::numeric, 1)::float AS distance_pct",
                "ABS(#{DISTANCE}) AS distance_rank")
        .order("distance_rank DESC", "employees.id")
    end
  end
end
