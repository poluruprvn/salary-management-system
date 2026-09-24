require 'rails_helper'

RSpec.describe SalaryRevisions::Update do
  let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }
  let(:revision) { create(:salary_revision, employee: employee, effective_date: Date.new(2024, 4, 1), amount_cents: 12_000_000) }

  it "updates the revision and returns it" do
    expect(described_class.call(revision, amount_cents: 12_500_000, note: "typo")).to eq(revision)
    expect(revision.reload).to have_attributes(amount_cents: 12_500_000, note: "typo")
  end

  it "raises when the date moves out of the employment window" do
    expect { described_class.call(revision, effective_date: Date.new(2023, 12, 31)) }
      .to raise_error(ActiveRecord::RecordInvalid, /on or after the hire date/)
  end

  it "leaves the row and its trail as they were when it raises" do
    revision

    expect { described_class.call(revision, amount_cents: 0) }
      .to raise_error(ActiveRecord::RecordInvalid).and not_change { Audited::Audit.count }
    expect(revision.reload.amount_cents).to eq(12_000_000)
  end
end
