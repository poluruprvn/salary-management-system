require 'rails_helper'

RSpec.describe Employees::Update do
  let(:employee) { create(:employee, title: "Engineer", hire_date: Date.new(2024, 1, 1)) }

  it "updates the employee and returns it" do
    expect(described_class.call(employee, title: "Staff Engineer")).to eq(employee)
    expect(employee.reload.title).to eq("Staff Engineer")
  end

  it "raises on an invalid attribute" do
    expect { described_class.call(employee, email: "not an email") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "leaves the row and its trail as they were when it raises" do
    create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1))

    expect { described_class.call(employee, hire_date: Date.new(2024, 6, 1)) }
      .to raise_error(ActiveRecord::RecordInvalid).and not_change { Audited::Audit.count }
    expect(employee.reload.hire_date).to eq(Date.new(2024, 1, 1))
  end
end
