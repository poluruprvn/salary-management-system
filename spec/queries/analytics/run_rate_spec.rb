require "rails_helper"

RSpec.describe Analytics::RunRate do
  include_context "analytics population"

  def run_rate(group_by: "department", date: as_of)
    Analytics::RunRate.call(as_of: date, group_by: group_by).map do |row|
      [ row.is_total ? :total : row.group_id, row.slice(:headcount, :salaried, :gross_cents, :loaded_cents).symbolize_keys ]
    end
  end

  def totals(date = as_of) = run_rate(date: date).to_h.fetch(:total)

  it "sums each group and the total, loaded rounded per employee, costliest group first" do
    2.times { hire(salary: 1_000_005) }
    hire
    hire(salary: 2_000_000, department: sales, country: india)

    expect(run_rate).to eq([
      [ sales.id, { headcount: 1, salaried: 1, gross_cents: 2_000_000, loaded_cents: 3_000_000 } ],
      # 1_000_005 * 1.1 is 1_100_005.5 and rounds up for each of the two, so the group is not 2_200_011.
      [ engineering.id, { headcount: 3, salaried: 2, gross_cents: 2_000_010, loaded_cents: 2_200_012 } ],
      [ :total, { headcount: 4, salaried: 3, gross_cents: 4_000_010, loaded_cents: 5_200_012 } ]
    ])
  end

  it "groups by country and by level" do
    frenchman = hire(salary: 1_000_000)
    hire(salary: 3_000_000, country: india)

    expect(run_rate(group_by: "country").map(&:first)).to eq([ india.id, france.id, :total ])
    expect(run_rate(group_by: "level").map(&:first)).to include(frenchman.level_id)
  end

  it "returns a zero total when nobody is active" do
    expect(run_rate).to eq([ [ :total, { headcount: 0, salaried: 0, gross_cents: 0, loaded_cents: 0 } ] ])
  end

  it "ignores a future dated raise until as_of reaches it" do
    employee = hire(salary: 1_000_000)
    create(:salary_revision, employee: employee, effective_date: Date.new(2024, 9, 1), amount_cents: 2_000_000)

    expect(totals(Date.new(2024, 8, 31))).to include(gross_cents: 1_000_000)
    expect(totals(Date.new(2024, 9, 1))).to include(gross_cents: 2_000_000)
  end

  it "ignores a voided revision" do
    employee = hire(salary: 1_000_000)
    create(:salary_revision, :voided, employee: employee, effective_date: Date.new(2024, 3, 1), amount_cents: 9_000_000)

    expect(totals).to include(gross_cents: 1_000_000)
  end

  it "counts an employee on their exit date and not the day after" do
    hire(salary: 1_000_000, exit_date: as_of)

    expect(totals).to include(headcount: 1, gross_cents: 1_000_000)
    expect(totals(as_of + 1)).to include(headcount: 0, gross_cents: 0)
  end

  it "does not count a pending hire" do
    hire(hire_date: as_of + 1)

    expect(totals).to include(headcount: 0)
  end

  it "refuses an unknown group" do
    expect { Analytics::RunRate.call(as_of: as_of, group_by: "title") }
      .to raise_error(InvalidParameter, "group_by must be one of department, country, level")
  end
end
