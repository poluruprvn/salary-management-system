module Analytics
  class Distribution
    # Grouped on the joined table's primary key, or on the title itself, so the name and sort
    # columns need no GROUP BY entry of their own.
    GROUP_KEYS = {
      "department" => { id: "departments.id", name: "departments.name", sort: "lower(departments.name)", joins: :department },
      "country" => { id: "countries.id", name: "countries.name", sort: "lower(countries.name)", joins: :country },
      "level" => { id: "levels.id", name: "levels.name", sort: "levels.rank", joins: :level },
      "title" => { id: "employees.title", name: "employees.title", sort: "lower(employees.title)", default_sort: "-headcount" }
    }.freeze

    # Percentiles of the salaried, per group. Someone with no salary has no rank, so they are
    # counted by summary instead.
    def self.call(as_of:, group_by:, filters: {}, sort: nil)
      key = group_key(group_by)
      sort = sort.to_s.presence || key.fetch(:default_sort, "name")
      column = { "name" => key[:sort], "headcount" => "headcount", "median" => "median_cents" }
        .fetch(sort.delete_prefix("-")) { raise UnknownSortKey, sort }

      population(as_of, filters, key)
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

    # How many groups `call` returns, for paging, and how many people it leaves out for having no salary.
    def self.summary(as_of:, group_by:, filters: {})
      key = group_key(group_by)

      population(as_of, filters, key)
        .select("COUNT(DISTINCT #{key[:id]}) FILTER (WHERE current_salary.amount_cents IS NOT NULL) AS groups",
                "COUNT(*) FILTER (WHERE current_salary.amount_cents IS NULL) AS unsalaried")
    end

    def self.group_key(group_by)
      GROUP_KEYS.fetch(group_by.to_s) { raise InvalidParameter.new(:group_by, "must be one of #{GROUP_KEYS.keys.join(", ")}") }
    end

    def self.population(as_of, filters, key)
      relation = Employees::List.filter(filters, as_of: as_of).active_as_of(as_of).joins_salary_as_of(as_of)
      key[:joins] ? relation.joins(key[:joins]) : relation
    end

    # percentile_cont takes double precision only. The cast to numeric keeps 15 significant digits,
    # and amounts are capped below 10^12 cents, so the fraction survives and numeric rounds it half up.
    def self.percentile(fraction, name)
      "ROUND((percentile_cont(#{fraction}) WITHIN GROUP (ORDER BY current_salary.amount_cents))::numeric)::bigint AS #{name}"
    end

    private_class_method :group_key, :population, :percentile
  end
end
