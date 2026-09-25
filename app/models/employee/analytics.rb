module Employee::Analytics
  extend ActiveSupport::Concern

  # The grouping sets are spelled out, not interpolated, so brakeman sees a literal.
  GROUP_KEYS = {
    "department" => { column: "employees.department_id", grouping_sets: "GROUPING SETS ((employees.department_id), ())" },
    "country" => { column: "employees.country_id", grouping_sets: "GROUPING SETS ((employees.country_id), ())" },
    "level" => { column: "employees.level_id", grouping_sets: "GROUPING SETS ((employees.level_id), ())" }
  }.freeze

  # Grouped on the joined table's primary key, or on the title itself, so the name and sort
  # columns need no GROUP BY entry of their own.
  DISTRIBUTION_KEYS = {
    "department" => { id: "departments.id", name: "departments.name", sort: "lower(departments.name)", joins: :department },
    "country" => { id: "countries.id", name: "countries.name", sort: "lower(countries.name)", joins: :country },
    "level" => { id: "levels.id", name: "levels.name", sort: "levels.rank", joins: :level },
    "title" => { id: "employees.title", name: "employees.title", sort: "lower(employees.title)", default_sort: "-headcount" }
  }.freeze

  # Below five, each quartile holds at most one person, and the fence says nothing.
  MIN_COHORT = 5

  OUTSIDE_FENCE = {
    "below" => "salaried.amount_cents < cohort_stats.lower_fence",
    "above" => "salaried.amount_cents > cohort_stats.upper_fence"
  }.freeze

  DISTANCE = "(salaried.amount_cents - cohort_stats.p50) / cohort_stats.p50 * 100"

  RUN_RATE_AMOUNTS = [
    "COUNT(*) AS headcount",
    "COUNT(current_salary.amount_cents) AS salaried",
    "COALESCE(SUM(current_salary.amount_cents), 0)::bigint AS gross_cents",
    "COALESCE(SUM(ROUND(current_salary.amount_cents * countries.employer_cost_multiplier)), 0)::bigint AS loaded_cents"
  ].freeze

  class_methods do
    # One row per group plus the total row, from one scan, so the total always foots. Loaded rounds
    # per employee before the sum, so a group is the sum of its rows.
    def run_rate(as_of:, group_by:)
      key = closed_group(GROUP_KEYS, group_by)

      active_as_of(as_of)
        .joins(:country)
        .joins(sanitize_sql_array([ Employee::SALARY_AS_OF_JOIN, { as_of: as_of } ]))
        .group(key[:grouping_sets])
        .select("#{key[:column]} AS group_id",
                "GROUPING(#{key[:column]}) = 1 AS is_total",
                *RUN_RATE_AMOUNTS)
        .order("is_total", "loaded_cents DESC", "group_id")
    end

    # Percentiles of the salaried, per group. Someone with no salary has no rank, so they are
    # counted by distribution_summary instead.
    def distribution(as_of:, group_by:, filters: {}, sort: nil)
      key = closed_group(DISTRIBUTION_KEYS, group_by)
      sort = sort.to_s.presence || key.fetch(:default_sort, "name")
      column = { "name" => key[:sort], "headcount" => "headcount", "median" => "median_cents" }
        .fetch(sort.delete_prefix("-")) { raise UnknownSortKey, sort }

      distribution_population(as_of, filters, key)
        .where.not(current_salary: { amount_cents: nil })
        .group(key[:id])
        .select("#{key[:id]} AS group_id",
                "#{key[:name]} AS group_name",
                "COUNT(*) AS headcount",
                "MIN(current_salary.amount_cents) AS min_cents",
                percentile(0.25, "p25_cents"),
                percentile(0.5, "median_cents"),
                percentile(0.75, "p75_cents"),
                "MAX(current_salary.amount_cents) AS max_cents")
        .order("#{column} #{sort.start_with?("-") ? "DESC" : "ASC"}", "group_id")
    end

    # How many groups distribution has, for paging, and how many it left out for having no salary.
    def distribution_summary(as_of:, group_by:, filters: {})
      key = closed_group(DISTRIBUTION_KEYS, group_by)

      distribution_population(as_of, filters, key)
        .select("COUNT(DISTINCT #{key[:id]}) FILTER (WHERE current_salary.amount_cents IS NOT NULL) AS groups",
                "COUNT(*) FILTER (WHERE current_salary.amount_cents IS NULL) AS unsalaried")
        .take
    end

    # Every level and country pair with a salaried active employee. The counts compare against the
    # unrounded fence, since rounding first can move someone across it by a cent.
    def cohorts(as_of:)
      unscoped.with_cohort_stats(as_of)
        .from("cohort_stats")
        .joins("JOIN levels ON levels.id = cohort_stats.level_id")
        .joins("JOIN countries ON countries.id = cohort_stats.country_id")
        .joins(<<~SQL.squish)
          CROSS JOIN LATERAL (
            SELECT COUNT(*) FILTER (WHERE #{OUTSIDE_FENCE["below"]}) AS below,
                   COUNT(*) FILTER (WHERE #{OUTSIDE_FENCE["above"]}) AS above
            FROM salaried
            WHERE salaried.level_id = cohort_stats.level_id AND salaried.country_id = cohort_stats.country_id
          ) outlier_counts
        SQL
        .select("cohort_stats.level_id", "levels.name AS level_name",
                "cohort_stats.country_id", "countries.name AS country_name",
                "cohort_stats.headcount", "cohort_stats.evaluated",
                *%w[p25 p50 p75 lower_fence upper_fence].map { |column| "ROUND(cohort_stats.#{column}::numeric)::bigint AS #{column}_cents" },
                "outlier_counts.below AS outliers_below", "outlier_counts.above AS outliers_above")
        .order("levels.rank", "lower(countries.name)", "cohort_stats.country_id")
    end

    # The filters narrow who is listed, never the cohort. The fence belongs to the whole level and
    # country, so the same person is an outlier on every screen or on none.
    def outliers(as_of:, filters: {}, direction: nil)
      outside =
        if direction.blank?
          OUTSIDE_FENCE.values.join(" OR ")
        else
          OUTSIDE_FENCE.fetch(direction.to_s) { raise InvalidParameter.new(:direction, "must be one of #{OUTSIDE_FENCE.keys.join(", ")}") }
        end

      filtered(filters, as_of: as_of)
        .with_cohort_stats(as_of)
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
                "CASE WHEN #{OUTSIDE_FENCE["below"]} THEN 'below' ELSE 'above' END AS direction",
                "ROUND((#{DISTANCE})::numeric, 1)::float AS distance_pct",
                "ABS(#{DISTANCE}) AS distance_rank")
        .order("distance_rank DESC", "employees.id")
    end

    # Two CTEs: salaried is the active population with a salary in force, and cohort_stats its
    # quartiles and fences per level and country. The fences are null below MIN_COHORT, and when
    # p25 equals p75, since both fences then sit on the median and a cent away from it is outside.
    # Nobody in such a cohort compares as outside.
    def with_cohort_stats(as_of)
      salaried = unscoped.active_as_of(as_of)
        .joins(sanitize_sql_array([ Employee::SALARY_AS_OF_JOIN, { as_of: as_of } ]))
        .where.not(current_salary: { amount_cents: nil })
        .select("employees.id", "employees.level_id", "employees.country_id", "current_salary.amount_cents")
      quartiles = unscoped.from("salaried")
        .group("level_id", "country_id")
        .select("level_id", "country_id", "COUNT(*) AS headcount",
                *{ p25: 0.25, p50: 0.5, p75: 0.75 }.map { |name, fraction| "percentile_cont(#{fraction}) WITHIN GROUP (ORDER BY amount_cents) AS #{name}" })
      evaluated = "headcount >= #{MIN_COHORT} AND p75 > p25"
      cohort_stats = unscoped.from(quartiles, :quartiles)
        .select("quartiles.*", "#{evaluated} AS evaluated",
                "CASE WHEN #{evaluated} THEN p25 - 1.5 * (p75 - p25) END AS lower_fence",
                "CASE WHEN #{evaluated} THEN p75 + 1.5 * (p75 - p25) END AS upper_fence")

      with(salaried: salaried, cohort_stats: cohort_stats)
    end

    # The last day of each of the twelve months before as_of's month, then as_of itself.
    def trend_dates(as_of)
      [ *12.downto(1).map { |months| (as_of << months).end_of_month }, as_of ]
    end

    # The run rate at each date, and what moved in the interval that date closes. The first date
    # closes no interval, so its movement is null. The exit date is paid, so an exit counts where
    # headcount drops: in the interval holding the day after it. A raise is a live revision with a live one before
    # it, so a starting salary is not one.
    def trend(as_of:)
      dates = trend_dates(as_of)
      points = unscoped
        .from(sanitize_sql_array([ "unnest(ARRAY[:dates]::date[], ARRAY[:previous]::date[]) AS points(date, previous_date)",
                                   { dates: dates, previous: [ nil, *dates[...-1] ] } ]))
        .select("points.*")
      run_rate = unscoped.where("employees.hire_date <= points.date AND (employees.exit_date IS NULL OR employees.exit_date >= points.date)")
        .joins(:country)
        .joins(at_point(Employee::SALARY_AS_OF_JOIN))
        .select(*RUN_RATE_AMOUNTS)
      # Joined to the window's output, not filtered inside it, or LAG loses the previous revision.
      # A plain join rather than a lateral, so the window runs once and not once per point.
      revisions = SalaryRevision.live.select("salary_revisions.effective_date", "salary_revisions.amount_cents", SalaryRevision::PREVIOUS_AMOUNT)
      raises = unscoped.from("points")
        .joins(<<~SQL.squish)
          LEFT JOIN (#{revisions.to_sql}) revisions ON revisions.previous_amount_cents IS NOT NULL
            AND revisions.effective_date > points.previous_date AND revisions.effective_date <= points.date
        SQL
        .group("points.date")
        .select("points.date", "COUNT(revisions.amount_cents) AS raises",
                "COALESCE(SUM(revisions.amount_cents - revisions.previous_amount_cents), 0)::bigint AS raise_delta_cents")

      unscoped.with(points: points, raises: raises)
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

    private
      # The salary lateral, read at each trend point instead of one bound date.
      def at_point(sql)
        sql.gsub(":as_of", "points.date")
      end

      def closed_group(keys, key)
        keys.fetch(key.to_s) { raise InvalidParameter.new(:group_by, "must be one of #{keys.keys.join(", ")}") }
      end

      def distribution_population(as_of, filters, key)
        relation = filtered(filters, as_of: as_of).active_as_of(as_of)
          .joins(sanitize_sql_array([ Employee::SALARY_AS_OF_JOIN, { as_of: as_of } ]))
        key[:joins] ? relation.joins(key[:joins]) : relation
      end

      # percentile_cont takes double precision only. The cast to numeric keeps 15 significant digits,
      # and amounts are capped below 10^12 cents, so the fraction survives and numeric rounds it half up.
      def percentile(fraction, name)
        "ROUND((percentile_cont(#{fraction}) WITHIN GROUP (ORDER BY current_salary.amount_cents))::numeric)::bigint AS #{name}"
      end
  end
end
