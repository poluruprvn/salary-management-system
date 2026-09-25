require "rails_helper"

RSpec.describe "Analytics::Cohorts and Analytics::Outliers" do
  include_context "analytics population"

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

  def cohorts = Analytics::Cohorts.call(as_of: as_of).to_h { |row| [ [ row.level_id, row.country_id ], row ] }

  def outliers(**options)
    Analytics::Outliers.call(as_of: as_of, **options).map { |row| [ row.id, row.direction, row.distance_pct ] }
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

    expect(cohorts[[ l5.id, france.id ]]).to have_attributes(
      headcount: 4, evaluated: false, lower_fence_cents: nil, upper_fence_cents: nil, outliers_below: nil, reason: "fewer than 5 people"
    )
    expect(outliers.map(&:first)).not_to include(far.id)
  end

  it "does not evaluate a cohort whose p25 equals its p75" do
    4.times { hire(salary: 1_000_000, level: l4) }
    cent_above = hire(salary: 1_000_001, level: l4)

    expect(cohorts[[ l4.id, france.id ]]).to have_attributes(
      headcount: 5, evaluated: false, upper_fence_cents: nil, outliers_above: nil, reason: "p25 and p75 are equal"
    )
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
    median = Analytics::Distribution.call(as_of: as_of, group_by: "level", filters: { country_id: [ france.id ] })
      .find { |row| row.group_id == l5.id }.median_cents

    expect(median).to eq(1_000_001)
    expect(cohorts[[ l5.id, france.id ]].p50_cents).to eq(median)
  end

  it "refuses an unknown direction" do
    expect { Analytics::Outliers.call(as_of: as_of, direction: "sideways") }
      .to raise_error(InvalidParameter, "direction must be one of below, above")
  end
end
