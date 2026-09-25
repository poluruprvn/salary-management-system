module Employees
  class List
    # lower() because postgres:18-alpine is musl, which collates bytewise and puts every capital
    # first. level sorts by rank, since as text L10 sorts before L2. exit_date and salary can be
    # null, and Postgres puts nulls first on DESC.
    SORT_KEYS = {
      "name" => { asc: "lower(employees.name) ASC", desc: "lower(employees.name) DESC" },
      "hire_date" => { asc: "employees.hire_date ASC", desc: "employees.hire_date DESC" },
      "exit_date" => { asc: "employees.exit_date ASC NULLS LAST", desc: "employees.exit_date DESC NULLS LAST" },
      "salary" => { asc: "current_salary.amount_cents ASC NULLS LAST", desc: "current_salary.amount_cents DESC NULLS LAST" },
      "department" => { asc: "lower(departments.name) ASC", desc: "lower(departments.name) DESC", joins: :department },
      "country" => { asc: "lower(countries.name) ASC", desc: "lower(countries.name) DESC", joins: :country },
      "level" => { asc: "levels.rank ASC", desc: "levels.rank DESC", joins: :level }
    }.freeze

    # Filters only. No join and no order, so the page count never pays for the salary lookup.
    def self.filter(filters, as_of:)
      relation = Employee.all
      relation = search(relation, filters[:q]) if filters[:q].present?
      relation = relation.where(title: filters[:title]) if filters[:title].present?
      relation = with_status(relation, filters[:status].to_s, as_of) if filters[:status].present?

      %i[department_id country_id level_id].each do |key|
        ids = Array(filters[key]).compact_blank
        relation = relation.where(key => ids) if ids.any?
      end

      relation
    end

    # Sorting by salary reads the lateral, so the relation needs with_salary_as_of.
    def self.sort(relation, sort)
      sort = sort.to_s.presence || "name"
      key = SORT_KEYS.fetch(sort.delete_prefix("-")) { raise UnknownSortKey, sort }

      relation = relation.joins(key[:joins]) if key[:joins]
      # Every key has ties, so the id tiebreak fixes their order and offset pages never repeat or
      # skip a row.
      relation.order(key[sort.start_with?("-") ? :desc : :asc], :id)
    end

    # ILIKE has no operator for uuid, so an id is an exact match instead. Nobody types part of one.
    def self.search(relation, term)
      term = term.to_s.squish

      if (id = Employee.type_for_attribute(:id).cast(term))
        relation.where(id: id)
      else
        relation.where("employees.name ILIKE :pattern OR employees.email ILIKE :pattern OR employees.title ILIKE :pattern",
                       pattern: "%#{Employee.sanitize_sql_like(term)}%")
      end
    end

    def self.with_status(relation, status, as_of)
      raise InvalidParameter.new(:status, "must be one of #{Employee::STATUSES.join(", ")}") unless Employee::STATUSES.include?(status)

      relation.public_send("#{status}_as_of", as_of)
    end

    private_class_method :search, :with_status
  end
end
