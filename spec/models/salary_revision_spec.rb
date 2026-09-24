require "rails_helper"

# == Schema Information
#
# Table name: salary_revisions
#
#  id             :uuid             not null, primary key
#  amount_cents   :bigint           not null
#  effective_date :date             not null
#  note           :text
#  reason         :string           not null
#  voided_at      :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  employee_id    :uuid             not null
#
# Indexes
#
#  index_salary_revisions_on_employee_id                          (employee_id)
#  index_salary_revisions_on_employee_id_and_live_effective_date  (employee_id,effective_date) UNIQUE WHERE (voided_at IS NULL)
#  index_salary_revisions_on_updated_at                           (updated_at)
#
# Foreign Keys
#
#  fk_rails_...  (employee_id => employees.id)
#
# Check Constraints
#
#  salary_revisions_amount_cents_positive  (amount_cents > 0)
#
RSpec.describe SalaryRevision do
  let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }

  it { is_expected.to belong_to(:employee) }

  it "accepts only the four reasons" do
    SalaryRevision::REASONS.each do |reason|
      expect(build(:salary_revision, employee: employee, reason: reason)).to be_valid
    end

    expect(build(:salary_revision, employee: employee, reason: "bonus")).not_to be_valid
  end

  it "rejects an amount of zero or less" do
    expect(build(:salary_revision, employee: employee, amount_cents: 0)).not_to be_valid
    expect(build(:salary_revision, employee: employee, amount_cents: -1)).not_to be_valid
  end

  it "rejects an amount past the cap rather than overflowing the column" do
    expect(build(:salary_revision, employee: employee, amount_cents: 2**63)).not_to be_valid
  end

  it "holds the amount in a check constraint when the validation is skipped" do
    revision = build(:salary_revision, employee: employee, amount_cents: 0)

    expect { revision.save!(validate: false) }.to raise_error(ActiveRecord::CheckViolation)
  end

  it "updates an ordinary revision without complaining about its own date" do
    revision = create(:salary_revision, employee: employee, effective_date: Date.new(2024, 4, 1))

    expect { revision.update!(amount_cents: 13_000_000) }.not_to raise_error
  end

  describe "the effective date" do
    it "cannot fall before the hire date" do
      revision = build(:salary_revision, employee: employee, effective_date: Date.new(2023, 12, 31))

      expect(revision).not_to be_valid
      expect(revision.errors[:effective_date]).to include("must be on or after the hire date")
    end

    it "cannot fall after the exit date" do
      employee.update!(exit_date: Date.new(2024, 6, 30))
      revision = build(:salary_revision, employee: employee, effective_date: Date.new(2024, 7, 1))

      expect(revision).not_to be_valid
      expect(revision.errors[:effective_date]).to include("must be on or before the exit date")
    end

    it "may fall on the exit date, which the register pays" do
      employee.update!(exit_date: Date.new(2024, 6, 30))

      expect(build(:salary_revision, employee: employee, effective_date: Date.new(2024, 6, 30))).to be_valid
    end

    it "may fall on the hire date" do
      expect(build(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1))).to be_valid
    end

    it "may fall in the future while the employee is still on the books" do
      expect(build(:salary_revision, employee: employee, effective_date: 6.months.from_now.to_date)).to be_valid
    end

    it "is rechecked when the date moves out of the window" do
      revision = create(:salary_revision, employee: employee, effective_date: Date.new(2024, 4, 1))

      expect(revision.update(effective_date: Date.new(2023, 12, 31))).to be(false)
      expect(revision.errors[:effective_date]).to include("must be on or after the hire date")
    end
  end

  describe "a revision stranded by a shortened employment" do
    let!(:revision) { create(:salary_revision, employee: employee, effective_date: Date.new(2024, 9, 1), reason: "promotion") }

    before { employee.update!(exit_date: Date.new(2024, 6, 30)) }

    it "can still be voided, which is the only way to retract it" do
      expect { revision.reload.update!(voided_at: Time.current) }.not_to raise_error
    end

    it "can still be annotated" do
      expect { revision.reload.update!(note: "retracted on exit") }.not_to raise_error
    end
  end

  describe "one live revision per employee per date" do
    before { create(:salary_revision, employee: employee, effective_date: Date.new(2024, 4, 1)) }

    it "rejects a second one on the same date" do
      duplicate = build(:salary_revision, employee: employee, effective_date: Date.new(2024, 4, 1))

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:effective_date]).to include("has already been taken")
    end

    it "rejects it in the partial index too when the validation is skipped" do
      duplicate = build(:salary_revision, employee: employee, effective_date: Date.new(2024, 4, 1))

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows the same date for another employee" do
      colleague = create(:employee, hire_date: Date.new(2024, 1, 1))

      expect(build(:salary_revision, employee: colleague, effective_date: Date.new(2024, 4, 1))).to be_valid
    end

    it "allows a replacement once the first is voided" do
      described_class.find_by(effective_date: Date.new(2024, 4, 1)).update!(voided_at: Time.current)

      expect(build(:salary_revision, employee: employee, effective_date: Date.new(2024, 4, 1))).to be_valid
    end

    it "allows a voided row to sit beside a live one on the same date" do
      voided = build(:salary_revision, :voided, employee: employee, effective_date: Date.new(2024, 4, 1))

      expect(voided).to be_valid
      expect { voided.save! }.not_to raise_error
    end
  end

  describe ".live" do
    it "excludes voided revisions" do
      live = create(:salary_revision, employee: employee, effective_date: Date.new(2024, 4, 1))
      create(:salary_revision, :voided, employee: employee, effective_date: Date.new(2024, 5, 1))

      expect(described_class.live).to contain_exactly(live)
    end
  end
end
