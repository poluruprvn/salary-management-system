module Employee::Analytics
  extend ActiveSupport::Concern

  GROUP_KEYS = {
    "department" => "employees.department_id",
    "country" => "employees.country_id",
    "level" => "employees.level_id"
  }.freeze

  class_methods do
    def group_column(key)
      GROUP_KEYS.fetch(key.to_s) do
        raise InvalidParameter.new(:group_by, "must be one of #{GROUP_KEYS.keys.join(", ")}")
      end
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
  end
end
