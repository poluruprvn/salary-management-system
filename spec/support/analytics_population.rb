RSpec.shared_context "analytics population" do
  let(:as_of) { Date.new(2024, 6, 1) }
  let(:france) { create(:country, employer_cost_multiplier: "1.1") }
  let(:india) { create(:country, employer_cost_multiplier: "1.5") }
  let(:engineering) { create(:department) }
  let(:sales) { create(:department) }

  def hire(salary: nil, department: engineering, country: france, **attrs)
    employee = create(:employee, department: department, country: country, hire_date: Date.new(2024, 1, 1), **attrs)
    create(:salary_revision, employee: employee, amount_cents: salary) if salary
    employee
  end
end
