require "rails_helper"

RSpec.describe "db/seeds.rb" do
  def seed
    Rails.application.load_seed
  end

  def row_counts
    [ User, Country, Department, Level, Employee, SalaryRevision, Audited::Audit ].to_h { |model| [ model.name, model.count ] }
  end

  def seeded_values
    Employee.joins(:salary_revisions).order(:email, "salary_revisions.effective_date")
      .pluck(:email, :title, :exit_date, "salary_revisions.effective_date", "salary_revisions.amount_cents")
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("SEED_EMPLOYEE_COUNT", anything).and_return("50")
  end

  it "writes nothing outside development and test" do
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))

    # exit or abort would end the run without a failure. raise_error catches SystemExit.
    expect { seed }.not_to raise_error
    expect(row_counts.values).to all(be_zero)
  end

  it "writes the same rows when run twice" do
    seed

    expect { seed }.not_to change { row_counts }
    expect(row_counts).to include("User" => 1, "Employee" => 50, "Audited::Audit" => 0)
  end

  it "writes the same rows when run again on a later day" do
    seed

    travel 45.days do
      expect { seed }.not_to change { row_counts }
    end
  end

  it "leaves a voided revision voided when run again" do
    seed
    SalaryRevision.first.update!(voided_at: Time.current)

    expect { seed }.not_to change { row_counts }
  end

  it "keeps every employee when names share an email handle" do
    allow(Faker::Name).to receive(:first_name).and_return("Ada", "Adá")
    allow(Faker::Name).to receive(:last_name).and_return("Lovelace")
    seed

    expect { seed }.not_to change { row_counts }
    expect(Employee.count).to eq(50)
    expect(Employee.pluck(:email)).to include("ada.lovelace@example.com", "ada.lovelace50@example.com")
  end

  it "renames no one when a draw is added after the name" do
    seed
    allow(Faker::Name).to receive(:last_name).and_wrap_original do |original|
      original.call.tap { Faker::Config.random.rand }
    end

    expect { seed }.not_to change(Employee, :count)
  end

  it "writes the same values into an empty database" do
    seed
    first = seeded_values
    SalaryRevision.delete_all
    Employee.delete_all
    seed

    expect(seeded_values).to eq(first)
  end

  it "writes only rows the skipped validations would accept" do
    # 50 has no pending hire and no leaver who draws the future raise.
    allow(ENV).to receive(:fetch).with("SEED_EMPLOYEE_COUNT", anything).and_return("300")
    seed

    expect(Employee.pending_as_of(Date.current)).to exist
    expect(Employee.all).to all(be_valid)
    expect(Employee.where.missing(:salary_revisions)).to be_empty
    expect(SalaryRevision.distinct.pluck(:reason)).to all(be_in(SalaryRevision::REASONS))
    expect(SalaryRevision.joins(:employee).where(
      "salary_revisions.effective_date < employees.hire_date OR salary_revisions.effective_date > employees.exit_date"
    )).to be_empty
  end

  it "creates the HR account from the environment" do
    allow(ENV).to receive(:fetch).with("SEED_HR_EMAIL", anything).and_return("boss@example.com")
    allow(ENV).to receive(:fetch).with("SEED_HR_PASSWORD", anything).and_return("correct horse battery staple")

    seed

    expect(User.sole.email).to eq("boss@example.com")
    expect(User.sole.authenticate("correct horse battery staple")).to be_truthy
  end

  it "rolls back and resets Faker when a write fails" do
    allow(SalaryRevision).to receive(:insert_all).and_raise(ActiveRecord::StatementInvalid)

    expect { seed }.to raise_error(ActiveRecord::StatementInvalid)
    expect(row_counts.values).to all(be_zero)
    expect(Faker::Config.random).to be(Random)
  end
end
