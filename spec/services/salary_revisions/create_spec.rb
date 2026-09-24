require 'rails_helper'

RSpec.describe SalaryRevisions::Create do
  let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }
  let(:attributes) { { amount_cents: 13_200_000, effective_date: Date.new(2024, 7, 1), reason: "merit" } }

  def revise(effective_date, amount_cents, *traits)
    create(:salary_revision, *traits, employee: employee, effective_date: effective_date, amount_cents: amount_cents)
  end

  it "returns the new revision with no previous when it is the first" do
    change = described_class.call(employee, attributes)

    expect(change.revision).to be_persisted
    expect(change.revision).to have_attributes(employee: employee, amount_cents: 13_200_000)
    expect(change.previous).to be_nil
  end

  it "returns the latest live revision it follows, and only this employee's" do
    revise(Date.new(2024, 1, 1), 12_000_000)
    april = revise(Date.new(2024, 4, 1), 12_500_000)
    create(:salary_revision, employee: create(:employee, hire_date: Date.new(2024, 1, 1)), effective_date: Date.new(2024, 5, 1))

    expect(described_class.call(employee, attributes).previous).to eq(april)
  end

  it "returns the revision before a backdated one, not the one after it" do
    january = revise(Date.new(2024, 1, 1), 12_000_000)
    revise(Date.new(2024, 9, 1), 14_000_000)

    expect(described_class.call(employee, attributes).previous).to eq(january)
  end

  it "skips a voided revision when finding the previous" do
    january = revise(Date.new(2024, 1, 1), 12_000_000)
    revise(Date.new(2024, 4, 1), 99_000_000, :voided)

    expect(described_class.call(employee, attributes).previous).to eq(january)
  end

  it "raises on an occupied date" do
    revise(Date.new(2024, 7, 1), 12_000_000)

    expect { described_class.call(employee, attributes) }.to raise_error(ActiveRecord::RecordInvalid, /already been taken/)
  end

  it "writes no row and no audit when it raises" do
    employee

    expect { described_class.call(employee, attributes.merge(reason: "bonus")) }
      .to raise_error(ActiveRecord::RecordInvalid).and not_change { [ SalaryRevision.count, Audited::Audit.count ] }
  end

  it "rolls back the insert and its audit when a later step raises" do
    employee
    allow(described_class::Change).to receive(:new).and_raise("boom")

    expect { described_class.call(employee, attributes) }
      .to raise_error("boom").and not_change { [ SalaryRevision.count, Audited::Audit.count ] }
  end
end
