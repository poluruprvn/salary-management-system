require "rails_helper"

RSpec.describe Analytics::Trend do
  include_context "analytics population"

  let(:as_of) { Date.new(2024, 6, 15) }

  def trend = Analytics::Trend.call(as_of: as_of).to_a
  def point(date) = trend.find { |row| row.date == date }

  it "ends each month before as_of's, then as_of itself" do
    expect(Analytics::Trend.dates(Date.new(2026, 3, 31)).map(&:iso8601)).to eq(%w[
      2025-03-31 2025-04-30 2025-05-31 2025-06-30 2025-07-31 2025-08-31 2025-09-30
      2025-10-31 2025-11-30 2025-12-31 2026-01-31 2026-02-28 2026-03-31
    ])
    expect(Analytics::Trend.dates(Date.new(2026, 3, 15))).to eq([ *Analytics::Trend.dates(Date.new(2026, 2, 28)).drop(1), Date.new(2026, 3, 15) ])
    expect(Analytics::Trend.dates(Date.new(2024, 2, 29)).values_at(0, 1, -2, -1))
      .to eq([ Date.new(2023, 2, 28), Date.new(2023, 3, 31), Date.new(2024, 1, 31), Date.new(2024, 2, 29) ])
  end

  it "gives each point the run rate at its date" do
    hire(salary: 1_000_005, hire_date: Date.new(2023, 3, 1))
    raised = hire(salary: 2_000_000, country: india, hire_date: Date.new(2023, 3, 1))
    create(:salary_revision, employee: raised, effective_date: Date.new(2024, 2, 1), amount_cents: 2_500_000)
    hire(salary: 1_000_000, hire_date: Date.new(2023, 9, 1), exit_date: Date.new(2024, 3, 31))
    hire(hire_date: Date.new(2024, 6, 1))

    expect(trend.map(&:date)).to eq(Analytics::Trend.dates(as_of))
    trend.each do |row|
      run_rate = Analytics::RunRate.call(as_of: row.date, group_by: "department").find(&:is_total)
      expect(row.slice(:headcount, :salaried, :gross_cents, :loaded_cents))
        .to eq(run_rate.slice(:headcount, :salaried, :gross_cents, :loaded_cents)), "at #{row.date}"
    end
  end

  it "counts hires, exits and raises in the interval each point closes, and none before the first" do
    hire(hire_date: Date.new(2024, 5, 1))
    hire(hire_date: Date.new(2023, 1, 1), exit_date: Date.new(2024, 5, 31))
    starting = create(:employee, hire_date: Date.new(2024, 5, 1))
    create(:salary_revision, employee: starting, effective_date: Date.new(2024, 5, 1), amount_cents: 1_000_000)
    create(:salary_revision, employee: starting, effective_date: Date.new(2024, 6, 1), amount_cents: 1_200_000)
    create(:salary_revision, :voided, employee: starting, effective_date: Date.new(2024, 6, 10), amount_cents: 9_000_000)
    create(:salary_revision, employee: starting, effective_date: Date.new(2024, 6, 15), amount_cents: 1_100_000)

    movement = ->(row) { row.slice(:hires, :exits, :raises, :raise_delta_cents).symbolize_keys }
    expect(movement.(point(Date.new(2023, 6, 30)))).to eq(hires: nil, exits: nil, raises: nil, raise_delta_cents: nil)
    expect(movement.(point(Date.new(2024, 4, 30)))).to eq(hires: 0, exits: 0, raises: 0, raise_delta_cents: 0)
    expect(movement.(point(Date.new(2024, 5, 31)))).to eq(hires: 2, exits: 0, raises: 0, raise_delta_cents: 0)
    expect(movement.(point(as_of))).to eq(hires: 0, exits: 1, raises: 2, raise_delta_cents: 100_000)
  end

  it "moves headcount by hires less exits at every point" do
    hire(hire_date: Date.new(2023, 1, 1), exit_date: Date.new(2024, 3, 31))
    hire(hire_date: Date.new(2023, 1, 1), exit_date: Date.new(2024, 4, 15))
    hire(hire_date: Date.new(2023, 1, 1), exit_date: Date.new(2024, 6, 15))
    hire(hire_date: Date.new(2024, 3, 31))
    hire(hire_date: Date.new(2024, 5, 10))

    trend.each_cons(2) do |previous, row|
      expect(row.headcount).to eq(previous.headcount + row.hires - row.exits), "at #{row.date}"
    end
  end
end
