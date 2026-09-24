require 'rails_helper'

RSpec.describe SalaryRevisions::Void do
  let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }
  let!(:january) { create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1), amount_cents: 12_000_000) }
  let(:april) { create(:salary_revision, employee: employee, effective_date: Date.new(2024, 4, 1), amount_cents: 13_000_000) }

  it "keeps the row and takes it out of the salary in force" do
    described_class.call(april)

    expect(april.reload.voided_at).to be_present
    expect(employee.salary_as_of(Date.new(2024, 6, 1))).to eq(january)
  end

  it "records the void as an update on the employee's trail" do
    described_class.call(april)

    expect(april.audits.last).to have_attributes(action: "update", associated: employee)
  end

  it "keeps the first timestamp when voided twice" do
    described_class.call(april)
    voided_at = april.reload.voided_at

    travel_to(1.day.from_now) { described_class.call(april) }

    expect(april.reload.voided_at).to eq(voided_at)
  end
end
