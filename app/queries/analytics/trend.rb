module Analytics
  class Trend
    # The last day of each of the twelve months before as_of's month, then as_of itself.
    def self.dates(as_of)
      [ *12.downto(1).map { |months| (as_of << months).end_of_month }, as_of ]
    end

    # The run rate at each date, and what moved in the interval that date closes. The first date
    # closes no interval, so its movement is null. The exit date is paid, so an exit counts where
    # headcount drops: in the interval holding the day after it. A raise is a live revision with a
    # live one before it, so a starting salary is not one.
    def self.call(as_of:)
      dates = self.dates(as_of)
      points = Employee.all
        .from(Employee.sanitize_sql_array([ "unnest(ARRAY[:dates]::date[], ARRAY[:previous]::date[]) AS points(date, previous_date)",
                                            { dates: dates, previous: [ nil, *dates[...-1] ] } ]))
        .select("points.*")
      run_rate = Employee.all
        .where("employees.hire_date <= points.date AND (employees.exit_date IS NULL OR employees.exit_date >= points.date)")
        .joins(:country)
        # Swaps the :as_of bind for points.date, so the lateral reads each point's date.
        .joins(Employee::SALARY_AS_OF_JOIN.gsub(":as_of", "points.date"))
        .select(*RunRate::AMOUNTS)
      # Joined to the window's output, not filtered inside it, or LAG loses the previous revision.
      # A plain join rather than a lateral, so the window runs once and not once per point.
      revisions = SalaryRevision.live.select("salary_revisions.effective_date", "salary_revisions.amount_cents", SalaryRevision::PREVIOUS_AMOUNT)
      raises = Employee.from("points")
        .joins(<<~SQL.squish)
          LEFT JOIN (#{revisions.to_sql}) revisions ON revisions.previous_amount_cents IS NOT NULL
            AND revisions.effective_date > points.previous_date AND revisions.effective_date <= points.date
        SQL
        .group("points.date")
        .select("points.date", "COUNT(revisions.amount_cents) AS raises",
                "COALESCE(SUM(revisions.amount_cents - revisions.previous_amount_cents), 0)::bigint AS raise_delta_cents")

      Employee.with(points: points, raises: raises)
        .from("points")
        .joins("CROSS JOIN LATERAL (#{run_rate.to_sql}) run_rate")
        .joins(<<~SQL.squish)
          LEFT JOIN LATERAL (
            SELECT (SELECT COUNT(*) FROM employees WHERE employees.hire_date > points.previous_date AND employees.hire_date <= points.date) AS hires,
                   (SELECT COUNT(*) FROM employees WHERE employees.exit_date >= points.previous_date AND employees.exit_date < points.date) AS exits,
                   raises.raises, raises.raise_delta_cents
            FROM raises
            WHERE raises.date = points.date
          ) movement ON points.previous_date IS NOT NULL
        SQL
        .select("points.date", "run_rate.*", "movement.*")
        .order("points.date")
    end
  end
end
