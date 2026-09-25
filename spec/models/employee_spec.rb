require "rails_helper"

# == Schema Information
#
# Table name: employees
#
#  id            :uuid             not null, primary key
#  email         :string           not null
#  exit_date     :date
#  hire_date     :date             not null
#  name          :string           not null
#  title         :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  country_id    :uuid             not null
#  department_id :uuid             not null
#  level_id      :uuid             not null
#
# Indexes
#
#  index_employees_on_country_id         (country_id)
#  index_employees_on_department_id      (department_id)
#  index_employees_on_exit_date          (exit_date)
#  index_employees_on_hire_date          (hire_date)
#  index_employees_on_level_id           (level_id)
#  index_employees_on_lower_email        (lower((email)::text)) UNIQUE
#  index_employees_on_lower_name_and_id  (lower((name)::text), id)
#  index_employees_on_title              (title)
#  index_employees_on_updated_at         (updated_at)
#
# Foreign Keys
#
#  fk_rails_...  (country_id => countries.id)
#  fk_rails_...  (department_id => departments.id)
#  fk_rails_...  (level_id => levels.id)
#
# Check Constraints
#
#  employees_exit_date_not_before_hire_date  (exit_date IS NULL OR exit_date >= hire_date)
#
RSpec.describe Employee do
  it { is_expected.to belong_to(:country) }
  it { is_expected.to belong_to(:department) }
  it { is_expected.to belong_to(:level) }
  it { is_expected.to have_many(:salary_revisions) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:hire_date) }
  it { is_expected.to validate_length_of(:name).is_at_most(255) }
  it { is_expected.to validate_length_of(:email).is_at_most(255) }
  it { is_expected.to validate_length_of(:title).is_at_most(255) }

  # Postgres reads 20240101 as a date, so without the strict type the row saved and only the
  # next comparison in Ruby raised.
  it "refuses a hire date that is a number, without raising on the way" do
    employee = build(:employee, hire_date: 20240101, exit_date: Date.new(2025, 1, 1))

    expect(employee).not_to be_valid
    expect(employee.errors[:hire_date]).to include("can't be blank")
  end

  it "downcases the email before validation" do
    employee = create(:employee, email: "Ada@Example.com")

    expect(employee.email).to eq("ada@example.com")
  end

  it "normalizes the email on update too, not only on create" do
    employee = create(:employee)
    employee.update!(email: "  Ada@Example.com  ")

    expect(employee.reload.email).to eq("ada@example.com")
  end

  it "squishes the title, so spacing does not split one title into two" do
    employee = create(:employee, title: "  Senior   Engineer ")

    expect(employee.title).to eq("Senior Engineer")
  end

  it "squishes the name, which is the default sort key" do
    employee = create(:employee, name: "  Ada   Lovelace ")

    expect(employee.name).to eq("Ada Lovelace")
  end

  it "rejects an address that is not an email" do
    expect(build(:employee, email: "not an email")).not_to be_valid
    expect(build(:employee, email: "ada lovelace@example.com")).not_to be_valid
    expect(build(:employee, email: "@example.com")).not_to be_valid
    expect(build(:employee, email: "ada.lovelace+hr@example.co.uk")).to be_valid
  end

  # URI::MailTo allows a bare host, so an intranet address is not rejected for missing a TLD.
  it "accepts an address with no dot in the host" do
    expect(build(:employee, email: "ada@example")).to be_valid
  end

  it "reports only the blank error for a missing email, not the format one" do
    record = build(:employee, email: "")

    record.valid?
    expect(record.errors[:email]).to contain_exactly("can't be blank")
  end

  it "rejects an email already taken in a different case" do
    create(:employee, email: "ada@example.com")

    expect(build(:employee, email: "ADA@example.com")).not_to be_valid
  end

  it "strips the email, so surrounding space is not a second employee" do
    create(:employee, email: "ada@example.com")

    expect(build(:employee, email: "  ada@example.com  ")).not_to be_valid
  end

  it "rejects it in the index too when the validation is skipped" do
    create(:employee, email: "ada@example.com")
    duplicate = build(:employee, email: "ADA@example.com")

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "refuses to destroy an employee with revisions" do
    employee = create(:employee)
    create(:salary_revision, employee: employee)

    expect(employee.destroy).to be(false)
    expect(employee.errors[:base]).to be_present
  end

  describe "exit date" do
    it "cannot fall before the hire date" do
      employee = build(:employee, hire_date: Date.new(2024, 1, 10), exit_date: Date.new(2024, 1, 9))

      expect(employee).not_to be_valid
      expect(employee.errors[:exit_date]).to include("must be on or after the hire date")
    end

    it "may fall on the hire date" do
      expect(build(:employee, hire_date: Date.new(2024, 1, 10), exit_date: Date.new(2024, 1, 10))).to be_valid
    end

    it "is held by a check constraint when the validation is skipped" do
      employee = build(:employee, hire_date: Date.new(2024, 1, 10), exit_date: Date.new(2024, 1, 9))

      expect { employee.save!(validate: false) }.to raise_error(ActiveRecord::CheckViolation)
    end

    it "refuses a value that is not a date, which would otherwise clear it" do
      employee = create(:employee, exit_date: Date.new(2025, 6, 30))

      [ "12/31/2025", 20251231, true, false ].each do |value|
        expect(employee.update(exit_date: value)).to be(false)
        expect(employee.errors[:exit_date]).to contain_exactly("is not a valid date")
      end
      expect(employee.reload.exit_date).to eq(Date.new(2025, 6, 30))
    end

    it "clears on nil or a blank string" do
      employee = create(:employee, exit_date: Date.new(2025, 6, 30))

      expect(employee.update(exit_date: "")).to be(true)
      expect(employee.reload.exit_date).to be_nil
    end
  end

  describe "the hire date" do
    let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }

    it "cannot move past a revision that is still live" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1))

      expect(employee.update(hire_date: Date.new(2025, 1, 1))).to be(false)
      expect(employee.errors[:hire_date]).to include("must be on or before the earliest revision on file")
    end

    it "may move past a voided one" do
      create(:salary_revision, :voided, employee: employee, effective_date: Date.new(2024, 1, 1))

      expect(employee.update(hire_date: Date.new(2025, 1, 1))).to be(true)
    end

    it "may still move earlier, which strands nothing" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 6, 1))

      expect(employee.update(hire_date: Date.new(2023, 1, 1))).to be(true)
    end
  end

  describe "#status_as_of" do
    let(:employee) { build(:employee, hire_date: Date.new(2024, 3, 1), exit_date: Date.new(2024, 9, 30)) }

    it "is pending the day before the hire date" do
      expect(employee.status_as_of(Date.new(2024, 2, 29))).to eq("pending")
    end

    it "is active on the hire date" do
      expect(employee.status_as_of(Date.new(2024, 3, 1))).to eq("active")
    end

    it "is active on the exit date, which the register pays" do
      expect(employee.status_as_of(Date.new(2024, 9, 30))).to eq("active")
    end

    it "is exited the day after the exit date" do
      expect(employee.status_as_of(Date.new(2024, 10, 1))).to eq("exited")
    end

    it "stays active without an exit date" do
      expect(build(:employee, hire_date: 1.year.ago.to_date, exit_date: nil).status_as_of).to eq("active")
    end

    it "defaults to today" do
      expect(build(:employee, hire_date: Date.current).status_as_of).to eq("active")
      expect(build(:employee, hire_date: Date.tomorrow).status_as_of).to eq("pending")
    end
  end

  describe "the status scopes" do
    let(:as_of) { Date.new(2024, 6, 1) }
    let!(:active) { create(:employee, hire_date: as_of, exit_date: nil) }
    let!(:leaving) { create(:employee, hire_date: Date.new(2024, 1, 1), exit_date: as_of) }
    let!(:resigned) { create(:employee, hire_date: Date.new(2024, 1, 1), exit_date: as_of + 30) }
    let!(:pending) { create(:employee, hire_date: as_of + 1) }
    let!(:exited) { create(:employee, hire_date: Date.new(2024, 1, 1), exit_date: as_of - 1) }
    let(:cohort) { [ active, leaving, resigned, pending, exited ] }

    def cohort_in(scope) = scope.where(id: cohort)

    it "counts an employee leaving that day, and one leaving later, as active" do
      expect(cohort_in(described_class.active_as_of(as_of))).to contain_exactly(active, leaving, resigned)
    end

    it "counts an employee hired the next day as pending" do
      expect(cohort_in(described_class.pending_as_of(as_of))).to contain_exactly(pending)
    end

    it "counts an employee who left the day before as exited" do
      expect(cohort_in(described_class.exited_as_of(as_of))).to contain_exactly(exited)
    end

    it "puts every employee in exactly one of them" do
      all = [ described_class.active_as_of(as_of), described_class.pending_as_of(as_of), described_class.exited_as_of(as_of) ]
        .flat_map { |scope| cohort_in(scope).to_a }

      expect(all).to match_array(cohort)
    end

    it "agrees with status_as_of on every row" do
      cohort.each do |employee|
        scope = described_class.public_send("#{employee.status_as_of(as_of)}_as_of", as_of)

        expect(cohort_in(scope)).to include(employee)
      end
    end

    it "names a scope for every status in the constant" do
      described_class::STATUSES.each do |status|
        expect(described_class).to respond_to("#{status}_as_of")
      end
    end

    it "returns nothing the constant does not name" do
      expect(cohort.map { |employee| employee.status_as_of(as_of) }).to all(be_in(described_class::STATUSES))
    end
  end

  describe "#salary_as_of" do
    let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }

    it "is nil with no revisions" do
      expect(employee.salary_as_of(Date.new(2024, 6, 1))).to be_nil
    end

    it "is nil when every revision is still in the future" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 7, 1))

      expect(employee.salary_as_of(Date.new(2024, 6, 1))).to be_nil
    end

    it "takes the revision effective that very day" do
      revision = create(:salary_revision, employee: employee, effective_date: Date.new(2024, 6, 1))

      expect(employee.salary_as_of(Date.new(2024, 6, 1))).to eq(revision)
    end

    it "takes the latest revision on or before the date and ignores later ones" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1))
      april = create(:salary_revision, employee: employee, effective_date: Date.new(2024, 4, 1))
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 9, 1))

      expect(employee.salary_as_of(Date.new(2024, 6, 1))).to eq(april)
    end

    it "ignores a voided revision" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1), amount_cents: 10_000_000)
      create(:salary_revision, :voided, employee: employee, effective_date: Date.new(2024, 4, 1), amount_cents: 99_000_000)

      expect(employee.salary_as_of(Date.new(2024, 6, 1)).amount_cents).to eq(10_000_000)
    end

    it "pays the exit date but nothing after it" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1))
      employee.update!(exit_date: Date.new(2024, 3, 31))

      expect(employee.salary_as_of(Date.new(2024, 3, 31))).to be_present
      expect(employee.salary_as_of(Date.new(2024, 4, 1))).to be_nil
    end

    it "is nil before the employee starts" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1))

      expect(employee.salary_as_of(Date.new(2023, 12, 31))).to be_nil
    end
  end

  describe ".with_salary_as_of" do
    let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }

    def salary_on(date) = described_class.with_salary_as_of(date).find(employee.id).current_salary_amount_cents

    it "is nil with no revisions, and still returns the employee" do
      expect(salary_on(Date.new(2024, 6, 1))).to be_nil
    end

    it "is nil when every revision is still in the future" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 7, 1))

      expect(salary_on(Date.new(2024, 6, 1))).to be_nil
    end

    it "takes the revision effective that very day, with its date" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 6, 1), amount_cents: 13_000_000)

      row = described_class.with_salary_as_of(Date.new(2024, 6, 1)).find(employee.id)

      expect(row.current_salary_amount_cents).to eq(13_000_000)
      expect(row.current_salary_effective_date).to eq(Date.new(2024, 6, 1))
    end

    it "ignores a future dated raise until as_of reaches it" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1), amount_cents: 12_000_000)
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 9, 1), amount_cents: 13_200_000)

      expect(salary_on(Date.new(2024, 8, 31))).to eq(12_000_000)
      expect(salary_on(Date.new(2024, 9, 1))).to eq(13_200_000)
    end

    it "does not see a voided revision" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1), amount_cents: 10_000_000)
      create(:salary_revision, :voided, employee: employee, effective_date: Date.new(2024, 4, 1), amount_cents: 99_000_000)

      expect(salary_on(Date.new(2024, 6, 1))).to eq(10_000_000)
    end

    it "pays the exit date but nothing after it" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1))
      employee.update!(exit_date: Date.new(2024, 3, 31))

      expect(salary_on(Date.new(2024, 3, 31))).to be_present
      expect(salary_on(Date.new(2024, 4, 1))).to be_nil
    end

    # insert_all skips the model guard, so seeded or imported data can hold a revision like this.
    it "is nil before the hire date even when a revision predates it" do
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1))
      employee.update_columns(hire_date: Date.new(2024, 3, 1))

      expect(salary_on(Date.new(2024, 2, 1))).to be_nil
    end

    it "agrees with salary_as_of for every employee on every boundary" do
      hired = Date.new(2024, 1, 1)
      raised = create(:employee, hire_date: hired)
      create(:salary_revision, employee: raised, effective_date: hired, amount_cents: 10_000_000)
      create(:salary_revision, employee: raised, effective_date: Date.new(2024, 6, 1), amount_cents: 11_000_000)
      leaver = create(:employee, hire_date: hired)
      create(:salary_revision, employee: leaver, effective_date: hired)
      leaver.update!(exit_date: Date.new(2024, 6, 1))
      voided = create(:employee, hire_date: hired)
      create(:salary_revision, :voided, employee: voided, effective_date: hired)
      cohort = [ raised, leaver, voided, create(:employee, hire_date: hired) ]

      [ hired - 1, hired, Date.new(2024, 5, 31), Date.new(2024, 6, 1), Date.new(2024, 6, 2) ].each do |date|
        listed = described_class.with_salary_as_of(date).where(id: cohort).to_h { |e| [ e.id, e.current_salary_amount_cents ] }

        expect(listed).to eq(cohort.to_h { |e| [ e.id, e.salary_as_of(date)&.amount_cents ] })
      end
    end

    it "joins once when chained twice on the same date" do
      relation = described_class.with_salary_as_of(Date.new(2024, 6, 1)).with_salary_as_of(Date.new(2024, 6, 1))

      expect(relation.to_sql.scan("LATERAL").size).to eq(1)
    end
  end

  describe ".title_counts" do
    def counts(term) = described_class.title_counts(term).map { |row| [ row.title, row.employee_count ] }

    it "counts each title across every employee, exited or not yet hired, most used first" do
      create_list(:employee, 2, title: "Senior Engineer")
      create(:employee, title: "Sr. Engineer", exit_date: Date.yesterday)
      create(:employee, title: "Senior Engineer", hire_date: Date.tomorrow)

      expect(counts(nil)).to eq([ [ "Senior Engineer", 3 ], [ "Sr. Engineer", 1 ] ])
    end

    it "breaks a tie on the title, ignoring case" do
      %w[Zookeeper analyst Buyer].each { |title| create(:employee, title: title) }

      expect(counts(nil).map(&:first)).to eq(%w[analyst Buyer Zookeeper])
    end

    it "matches anywhere in the title, ignoring case and extra spaces" do
      create(:employee, title: "Senior Data Engineer")
      create(:employee, title: "Accountant")

      expect(counts("  DATA   eng ")).to eq([ [ "Senior Data Engineer", 1 ] ])
    end

    it "treats % and _ as literal characters" do
      create(:employee, title: "Engineer")

      expect(counts("%")).to be_empty
      expect(counts("_")).to be_empty
    end
  end

  describe "#audit_trail" do
    let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }

    it "holds the employee's own changes and their revisions', newest first" do
      revision = create(:salary_revision, employee: employee)
      employee.update!(title: "Staff Engineer")
      create(:salary_revision, employee: create(:employee, hire_date: Date.new(2024, 1, 1)))

      expect(employee.audit_trail.map { |audit| [ audit.auditable, audit.action ] }).to eq([
        [ employee, "update" ], [ revision, "create" ], [ employee, "create" ]
      ])
    end

    # Frozen time gives every row the same created_at, which is the tie the id has to break.
    it "breaks a created_at tie on id, so offset pages never overlap" do
      freeze_time do
        employee
        3.times { |n| employee.update!(title: "Title #{n}") }

        expect(employee.audit_trail.map(&:created_at).uniq.size).to eq(1)
        expect(employee.audit_trail.map(&:version)).to eq([ 4, 3, 2, 1 ])
      end
    end
  end

  describe "auditing" do
    let(:employee) { create(:employee, title: "Engineer") }

    it "records a create" do
      audit = employee.audits.last

      expect(audit.action).to eq("create")
      expect(audit.audited_changes).to include("title" => "Engineer")
    end

    # The audited generator hardcodes auditable_id as an integer, and Rails casts a UUID through
    # to_i rather than raising, so every row would collapse onto 1 and auditable would be nil.
    it "round trips auditable_id as a uuid" do
      audit = employee.audits.last

      expect(audit.auditable_id).to eq(employee.id)
      expect(audit.auditable).to eq(employee)
    end

    it "records an update as a from-to pair" do
      employee.update!(title: "Staff Engineer")

      expect(employee.audits.last.audited_changes).to include("title" => [ "Engineer", "Staff Engineer" ])
    end

    it "writes nothing for a no-op update" do
      employee

      expect { employee.update!(title: "Engineer") }.not_to change { employee.audits.count }
    end

    it "writes nothing when the change is only to an ignored timestamp" do
      employee

      expect { employee.touch }.not_to change { employee.audits.count }
    end

    # audit_destroy is registered before the restrict_with_error callback, so the trail row is
    # inserted and then rolled back with the aborted destroy.
    it "rolls the trail back with a failed save" do
      create(:salary_revision, employee: employee)

      expect { employee.destroy }.not_to change(Audited::Audit, :count)
      expect(employee.reload).to be_persisted
    end

    it "leaves the actor nil when there is no controller" do
      expect(employee.audits.last.user).to be_nil
    end

    it "names the actor when one is declared" do
      user = create(:user)

      audit = Audited::Audit.as_user(user) { create(:employee) }.audits.last

      expect(audit.user).to eq(user)
    end
  end
end
