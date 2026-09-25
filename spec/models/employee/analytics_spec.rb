require "rails_helper"

RSpec.describe Employee::Analytics do
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

  describe ".run_rate" do
    def run_rate(group_by: "department", date: as_of)
      Employee.run_rate(as_of: date, group_by: group_by).map do |row|
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
      expect { Employee.run_rate(as_of: as_of, group_by: "title") }
        .to raise_error(InvalidParameter, "group_by must be one of department, country, level")
    end
  end

  describe ".distribution" do
    let!(:l4) { create(:level) }
    let!(:l5) { create(:level) }

    def distribution(group_by: "level", **options)
      Employee.distribution(as_of: as_of, group_by: group_by, **options).map do |row|
        [ row.group_id, row.slice(:headcount, :min_cents, :p25_cents, :median_cents, :p75_cents, :max_cents).symbolize_keys ]
      end
    end

    def summary(group_by: "level", **options)
      Employee.distribution_summary(as_of: as_of, group_by: group_by, **options).slice(:groups, :unsalaried).symbolize_keys
    end

    it "interpolates percentiles and rounds them half up to the cent" do
      [ 1_000_000, 1_000_001, 1_000_002, 1_000_004 ].each { |salary| hire(salary: salary, level: l4) }

      # p25 sits at 0.75 of the way from 1_000_000 to 1_000_001, p75 at 0.25 from 1_000_002 to 1_000_004.
      expect(distribution).to eq([
        [ l4.id, { headcount: 4, min_cents: 1_000_000, p25_cents: 1_000_001, median_cents: 1_000_002, p75_cents: 1_000_003, max_cents: 1_000_004 } ]
      ])
    end

    it "rounds an exact half cent up" do
      [ 1_000_000, 1_000_001 ].each { |salary| hire(salary: salary, level: l4) }

      expect(distribution.sole.last).to include(median_cents: 1_000_001)
    end

    it "leaves out the unsalaried and counts them in the summary" do
      hire(salary: 1_000_000, level: l4)
      hire(level: l4)
      hire(level: l5)

      expect(distribution.map(&:first)).to eq([ l4.id ])
      expect(summary).to eq(groups: 1, unsalaried: 2)
    end

    it "narrows the population before grouping" do
      hire(salary: 1_000_000, level: l4)
      hire(salary: 9_000_000, level: l4, department: sales, country: india)
      hire(salary: 5_000_000, level: l5, title: "Staff Engineer")

      expect(distribution(filters: { department_id: [ sales.id ], country_id: india.id }))
        .to match([ [ l4.id, a_hash_including(headcount: 1, median_cents: 9_000_000) ] ])
      expect(distribution(filters: { title: "Staff Engineer" }).map(&:first)).to eq([ l5.id ])
      expect(summary(filters: { country_id: [ france.id ] })).to eq(groups: 2, unsalaried: 0)
    end

    it "leaves out exited and pending employees" do
      hire(salary: 1_000_000, level: l4, exit_date: as_of - 1)
      hire(salary: 1_000_000, level: l4, hire_date: as_of + 1)

      expect(distribution).to be_empty
    end

    it "sorts levels by rank, and by headcount or median either way" do
      # Names that sort against rank, so only the rank gives this order.
      l4.update!(name: "Senior")
      l5.update!(name: "Associate")
      hire(salary: 1_000_000, level: l5)
      2.times { hire(salary: 2_000_000, level: l4) }

      expect(distribution.map(&:first)).to eq([ l4.id, l5.id ])
      expect(distribution(sort: "-name").map(&:first)).to eq([ l5.id, l4.id ])
      expect(distribution(sort: "headcount").map(&:first)).to eq([ l5.id, l4.id ])
      expect(distribution(sort: "-median").map(&:first)).to eq([ l4.id, l5.id ])
    end

    it "groups by title, most held first, and by department and country by name" do
      hire(salary: 1_000_000, title: "Analyst", department: sales)
      2.times { hire(salary: 1_000_000, title: "Zookeeper", department: sales) }
      hire(salary: 1_000_000, title: "analyst")
      sales.update!(name: "accounts")
      engineering.update!(name: "Bridge")

      expect(distribution(group_by: "title").map(&:first)).to eq([ "Zookeeper", "Analyst", "analyst" ])
      expect(distribution(group_by: "title", sort: "name").map(&:first)).to eq([ "Analyst", "analyst", "Zookeeper" ])
      expect(distribution(group_by: "department").map(&:first)).to eq([ sales.id, engineering.id ])
      expect(summary(group_by: "title")).to eq(groups: 3, unsalaried: 0)
    end

    it "groups by country, ordered by name ignoring case" do
      france.update!(name: "france")
      india.update!(name: "India")
      hire(salary: 1_000_000)
      2.times { hire(salary: 2_000_000, country: india) }

      expect(distribution(group_by: "country")).to match([
        [ france.id, a_hash_including(headcount: 1) ],
        [ india.id, a_hash_including(headcount: 2, median_cents: 2_000_000) ]
      ])
    end

    it "refuses an unknown group or sort" do
      expect { Employee.distribution(as_of: as_of, group_by: "email") }
        .to raise_error(InvalidParameter, "group_by must be one of department, country, level, title")
      expect { Employee.distribution(as_of: as_of, group_by: "level", sort: "salary") }.to raise_error(UnknownSortKey)
    end
  end

  describe "cohorts and outliers" do
    let(:l4) { create(:level) }
    let(:l5) { create(:level) }
    let!(:above) do
      [ 1_000_000, 1_000_000, 1_100_000, 1_200_000 ].each { |salary| hire(salary: salary, level: l5, country: india) }
      hire(salary: 1_600_000, level: l5, country: india, department: sales)
    end
    let!(:far_below) do
      [ 1_000_000, 1_100_000, 1_200_000, 1_200_000 ].each { |salary| hire(salary: salary, level: l4, country: india) }
      hire(salary: 300_000, level: l4, country: india)
    end

    def cohorts = Employee.cohorts(as_of: as_of).to_h { |row| [ [ row.level_id, row.country_id ], row ] }

    def outliers(**options)
      Employee.outliers(as_of: as_of, **options).map { |row| [ row.id, row.direction, row.distance_pct ] }
    end

    it "flags salaries outside the cohort's fence, farthest either way first, negative below the median" do
      expect(outliers).to eq([ [ far_below.id, "below", -72.7 ], [ above.id, "above", 45.5 ] ])
      expect(outliers(direction: "above")).to eq([ [ above.id, "above", 45.5 ] ])
      expect(cohorts[[ l4.id, india.id ]]).to have_attributes(
        headcount: 5, evaluated: true, p25_cents: 1_000_000, p50_cents: 1_100_000, p75_cents: 1_200_000,
        lower_fence_cents: 700_000, upper_fence_cents: 1_500_000, outliers_below: 1, outliers_above: 0
      )
    end

    it "does not flag a salary exactly on the fence" do
      [ 1_000_000, 1_000_000, 1_100_000, 1_200_000, 1_500_000 ].each { |salary| hire(salary: salary, level: l4) }

      expect(cohorts[[ l4.id, france.id ]]).to have_attributes(upper_fence_cents: 1_500_000, outliers_above: 0)
      expect(outliers.map(&:first)).to eq([ far_below.id, above.id ])
    end

    it "compares against the unrounded fence" do
      # p25 is 1_000_000 and p75 1_000_001, so the upper fence is 1_000_002.5 and shows as 1_000_003.
      [ 1_000_000, 1_000_000, 1_000_001, 1_000_001 ].each { |salary| hire(salary: salary, level: l4) }
      on_rounded_fence = hire(salary: 1_000_003, level: l4)

      expect(cohorts[[ l4.id, france.id ]]).to have_attributes(upper_fence_cents: 1_000_003, outliers_above: 1)
      expect(outliers.map(&:first)).to include(on_rounded_fence.id)
    end

    it "does not evaluate a cohort under five" do
      [ 1_000_000, 1_000_000, 1_000_000 ].each { |salary| hire(salary: salary, level: l5) }
      far = hire(salary: 9_000_000, level: l5)

      expect(cohorts[[ l5.id, france.id ]]).to have_attributes(headcount: 4, evaluated: false, lower_fence_cents: nil, upper_fence_cents: nil)
      expect(outliers.map(&:first)).not_to include(far.id)
    end

    it "does not evaluate a cohort whose p25 equals its p75" do
      4.times { hire(salary: 1_000_000, level: l4) }
      cent_above = hire(salary: 1_000_001, level: l4)

      expect(cohorts[[ l4.id, france.id ]]).to have_attributes(headcount: 5, evaluated: false, upper_fence_cents: nil, outliers_above: 0)
      expect(outliers.map(&:first)).not_to include(cent_above.id)
    end

    it "keeps exited and unsalaried employees out of every cohort" do
      hire(salary: 1_000_000, level: l4, country: india, exit_date: as_of - 1)
      hire(level: l4, country: india)

      expect(cohorts[[ l4.id, india.id ]].headcount).to eq(5)
    end

    it "filters who is listed, not who the fence is computed from" do
      expect(outliers(filters: { department_id: [ engineering.id ] }).map(&:first)).to eq([ far_below.id ])
      expect(outliers(filters: { country_id: [ france.id ] })).to be_empty
      expect(outliers(filters: { department_id: [ sales.id ] }).map(&:first)).to eq([ above.id ])
    end

    it "reports the same median as the distribution, rounded the same way" do
      # The middle pair is 1_000_000 and 1_000_001, so the median is 1_000_000.5.
      [ 900_000, 950_000, 1_000_000, 1_000_001, 1_050_000, 1_100_000 ].each { |salary| hire(salary: salary, level: l5) }
      median = Employee.distribution(as_of: as_of, group_by: "level", filters: { country_id: [ france.id ] })
        .find { |row| row.group_id == l5.id }.median_cents

      expect(median).to eq(1_000_001)
      expect(cohorts[[ l5.id, france.id ]].p50_cents).to eq(median)
    end

    it "refuses an unknown direction" do
      expect { Employee.outliers(as_of: as_of, direction: "sideways") }
        .to raise_error(InvalidParameter, "direction must be one of below, above")
    end
  end

  describe ".trend" do
    let(:as_of) { Date.new(2024, 6, 15) }

    def trend = Employee.trend(as_of: as_of).to_a
    def point(date) = trend.find { |row| row.date == date }

    it "ends each month before as_of's, then as_of itself" do
      expect(Employee.trend_dates(Date.new(2026, 3, 31)).map(&:iso8601)).to eq(%w[
        2025-03-31 2025-04-30 2025-05-31 2025-06-30 2025-07-31 2025-08-31 2025-09-30
        2025-10-31 2025-11-30 2025-12-31 2026-01-31 2026-02-28 2026-03-31
      ])
      expect(Employee.trend_dates(Date.new(2026, 3, 15))).to eq([ *Employee.trend_dates(Date.new(2026, 2, 28)).drop(1), Date.new(2026, 3, 15) ])
      expect(Employee.trend_dates(Date.new(2024, 2, 29)).values_at(0, 1, -2, -1))
        .to eq([ Date.new(2023, 2, 28), Date.new(2023, 3, 31), Date.new(2024, 1, 31), Date.new(2024, 2, 29) ])
    end

    it "gives each point the run rate at its date" do
      hire(salary: 1_000_005, hire_date: Date.new(2023, 3, 1))
      raised = hire(salary: 2_000_000, country: india, hire_date: Date.new(2023, 3, 1))
      create(:salary_revision, employee: raised, effective_date: Date.new(2024, 2, 1), amount_cents: 2_500_000)
      hire(salary: 1_000_000, hire_date: Date.new(2023, 9, 1), exit_date: Date.new(2024, 3, 31))
      hire(hire_date: Date.new(2024, 6, 1))

      expect(trend.map(&:date)).to eq(Employee.trend_dates(as_of))
      trend.each do |row|
        run_rate = Employee.run_rate(as_of: row.date, group_by: "department").find(&:is_total)
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
end
