require "rails_helper"

RSpec.describe Analytics::Distribution do
  include_context "analytics population"

  let!(:l4) { create(:level) }
  let!(:l5) { create(:level) }

  def distribution(group_by: "level", **options)
    Analytics::Distribution.call(as_of: as_of, group_by: group_by, **options).map do |row|
      [ row.group_id, row.slice(:headcount, :min_cents, :p25_cents, :median_cents, :p75_cents, :max_cents).symbolize_keys ]
    end
  end

  def summary(group_by: "level", **options)
    Analytics::Distribution.summary(as_of: as_of, group_by: group_by, **options).take.slice(:groups, :unsalaried).symbolize_keys
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
    expect { Analytics::Distribution.call(as_of: as_of, group_by: "email") }
      .to raise_error(InvalidParameter, "group_by must be one of department, country, level, title")
    expect { Analytics::Distribution.call(as_of: as_of, group_by: "level", sort: "salary") }.to raise_error(UnknownSortKey)
  end
end
