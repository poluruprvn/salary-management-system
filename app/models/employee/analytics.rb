module Employee::Analytics
  extend ActiveSupport::Concern

  GROUP_KEYS = {
    "department" => "employees.department_id",
    "country" => "employees.country_id",
    "level" => "employees.level_id"
  }.freeze

  # Grouped on the joined table's primary key, or on the title itself, so the name and sort
  # columns need no GROUP BY entry of their own.
  DISTRIBUTION_KEYS = {
    "department" => { id: "departments.id", name: "departments.name", sort: "lower(departments.name)", joins: :department },
    "country" => { id: "countries.id", name: "countries.name", sort: "lower(countries.name)", joins: :country },
    "level" => { id: "levels.id", name: "levels.name", sort: "levels.rank", joins: :level },
    "title" => { id: "employees.title", name: "employees.title", sort: "lower(employees.title)", default_sort: "-headcount" }
  }.freeze

  class_methods do
    def group_column(key)
      closed_group(GROUP_KEYS, key)
    end

    # One row per group plus the total row, from one scan, so the total always foots. Loaded rounds
    # per employee before the sum, so a group is the sum of its rows.
    def run_rate(as_of:, group_by:)
      column = group_column(group_by)

      active_as_of(as_of)
        .joins(:country)
        .joins(sanitize_sql_array([ Employee::SALARY_AS_OF_JOIN, { as_of: as_of } ]))
        .group("GROUPING SETS ((#{column}), ())")
        .select("#{column} AS group_id",
                "GROUPING(#{column}) = 1 AS is_total",
                "COUNT(*) AS headcount",
                "COUNT(current_salary.amount_cents) AS salaried",
                "COALESCE(SUM(current_salary.amount_cents), 0)::bigint AS gross_cents",
                "COALESCE(SUM(ROUND(current_salary.amount_cents * countries.employer_cost_multiplier)), 0)::bigint AS loaded_cents")
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

    private
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
