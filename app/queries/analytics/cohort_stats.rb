module Analytics
  module CohortStats
    # Below five, each quartile holds at most one person, and the fence says nothing.
    MIN_COHORT = 5

    OUTSIDE_FENCE = {
      "below" => "salaried.amount_cents < cohort_stats.lower_fence",
      "above" => "salaried.amount_cents > cohort_stats.upper_fence"
    }.freeze

    # Two CTEs: salaried is the active population with a salary in force, and cohort_stats its
    # quartiles and fences per level and country. The fences are null below MIN_COHORT, and when
    # p25 equals p75, since both fences then sit on the median and a cent away from it is outside.
    # Nobody in such a cohort compares as outside.
    def self.with(relation, as_of)
      salaried = Employee.active_as_of(as_of)
        .joins_salary_as_of(as_of)
        .where.not(current_salary: { amount_cents: nil })
        .select("employees.id", "employees.level_id", "employees.country_id", "current_salary.amount_cents")
      quartiles = Employee.from("salaried")
        .group("level_id", "country_id")
        .select("level_id", "country_id", "COUNT(*) AS headcount",
                *{ p25: 0.25, p50: 0.5, p75: 0.75 }.map { |name, fraction| "percentile_cont(#{fraction}) WITHIN GROUP (ORDER BY amount_cents) AS #{name}" })
      evaluated = "headcount >= #{MIN_COHORT} AND p75 > p25"
      cohort_stats = Employee.from(quartiles, :quartiles)
        .select("quartiles.*", "#{evaluated} AS evaluated",
                "CASE WHEN #{evaluated} THEN p25 - 1.5 * (p75 - p25) END AS lower_fence",
                "CASE WHEN #{evaluated} THEN p75 + 1.5 * (p75 - p25) END AS upper_fence")

      relation.with(salaried: salaried, cohort_stats: cohort_stats)
    end
  end
end
