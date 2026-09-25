module Analytics
  class RunRate
    # Spelled out, not interpolated, so brakeman sees literals. The name is a subquery on the grouped
    # id, so it needs no GROUP BY entry and is null on the total row.
    GROUPINGS = {
      "department" => {
        grouping_sets: "GROUPING SETS ((employees.department_id), ())",
        select: [ "employees.department_id AS group_id",
                  "(SELECT departments.name FROM departments WHERE departments.id = employees.department_id) AS group_name",
                  "GROUPING(employees.department_id) = 1 AS is_total" ]
      },
      "country" => {
        grouping_sets: "GROUPING SETS ((employees.country_id), ())",
        select: [ "employees.country_id AS group_id",
                  "(SELECT countries.name FROM countries WHERE countries.id = employees.country_id) AS group_name",
                  "GROUPING(employees.country_id) = 1 AS is_total" ]
      },
      "level" => {
        grouping_sets: "GROUPING SETS ((employees.level_id), ())",
        select: [ "employees.level_id AS group_id",
                  "(SELECT levels.name FROM levels WHERE levels.id = employees.level_id) AS group_name",
                  "GROUPING(employees.level_id) = 1 AS is_total" ]
      }
    }.freeze

    AMOUNTS = [
      "COUNT(*) AS headcount",
      "COUNT(current_salary.amount_cents) AS salaried",
      "COALESCE(SUM(current_salary.amount_cents), 0)::bigint AS gross_cents",
      "COALESCE(SUM(ROUND(current_salary.amount_cents * countries.employer_cost_multiplier)), 0)::bigint AS loaded_cents"
    ].freeze

    # One row per group plus the total row, from one scan, so the total always foots. Loaded rounds
    # per employee before the sum, so a group is the sum of its rows.
    def self.call(as_of:, group_by:)
      key = grouping(group_by)

      Employee.active_as_of(as_of)
        .joins(:country)
        .joins_salary_as_of(as_of)
        .group(key[:grouping_sets])
        .select(*key[:select], *AMOUNTS)
        .order("is_total", "loaded_cents DESC", "group_id")
    end

    def self.grouping(group_by)
      GROUPINGS.fetch(group_by.to_s) { raise InvalidParameter.new(:group_by, "must be one of #{GROUPINGS.keys.join(", ")}") }
    end

    private_class_method :grouping
  end
end
