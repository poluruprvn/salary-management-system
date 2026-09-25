module Analytics
  class Cohorts
    # Every level and country pair with a salaried active employee. The counts compare against the
    # unrounded fence, since rounding first can move someone across it by a cent.
    def self.call(as_of:)
      CohortStats.with(Employee.all, as_of)
        .from("cohort_stats")
        .joins("JOIN levels ON levels.id = cohort_stats.level_id")
        .joins("JOIN countries ON countries.id = cohort_stats.country_id")
        .joins(<<~SQL.squish)
          CROSS JOIN LATERAL (
            SELECT COUNT(*) FILTER (WHERE #{CohortStats::OUTSIDE_FENCE["below"]}) AS below,
                   COUNT(*) FILTER (WHERE #{CohortStats::OUTSIDE_FENCE["above"]}) AS above
            FROM salaried
            WHERE salaried.level_id = cohort_stats.level_id AND salaried.country_id = cohort_stats.country_id
          ) outlier_counts
        SQL
        .select("cohort_stats.level_id", "levels.name AS level_name",
                "cohort_stats.country_id", "countries.name AS country_name",
                "cohort_stats.headcount", "cohort_stats.evaluated",
                *%w[p25 p50 p75 lower_fence upper_fence].map { |column| "ROUND(cohort_stats.#{column}::numeric)::bigint AS #{column}_cents" },
                "CASE WHEN cohort_stats.evaluated THEN outlier_counts.below END AS outliers_below",
                "CASE WHEN cohort_stats.evaluated THEN outlier_counts.above END AS outliers_above",
                <<~SQL.squish)
                  CASE WHEN cohort_stats.headcount < #{CohortStats::MIN_COHORT} THEN 'fewer than #{CohortStats::MIN_COHORT} people'
                       WHEN NOT cohort_stats.evaluated THEN 'p25 and p75 are equal' END AS reason
                SQL
        .order("levels.rank", "lower(countries.name)", "cohort_stats.country_id")
    end
  end
end
