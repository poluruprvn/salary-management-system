class EmployeeSerializer
  def initialize(employee, as_of:)
    @employee = employee
    @as_of = as_of
  end

  def as_json(*)
    {
      id: @employee.id,
      name: @employee.name,
      email: @employee.email,
      title: @employee.title,
      hire_date: @employee.hire_date,
      exit_date: @employee.exit_date,
      status: @employee.status_as_of(@as_of),
      as_of: @as_of,
      country: CountrySerializer.new(@employee.country).as_json,
      department: DepartmentSerializer.new(@employee.department).as_json,
      level: LevelSerializer.new(@employee.level).as_json,
      current_salary: current_salary
    }
  end

  private
    # A list row carries the salary from the lateral join. A single record has no such column and
    # asks salary_as_of, which applies the same employment window.
    def current_salary
      amount_cents, effective_date =
        if @employee.has_attribute?(:current_salary_amount_cents)
          [ @employee.current_salary_amount_cents, @employee.current_salary_effective_date ]
        else
          @employee.salary_as_of(@as_of)&.then { |revision| [ revision.amount_cents, revision.effective_date ] }
        end

      { amount_cents: amount_cents, effective_date: effective_date } if amount_cents
    end
end
