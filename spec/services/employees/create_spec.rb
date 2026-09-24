require 'rails_helper'

RSpec.describe Employees::Create do
  let!(:attributes) do
    attributes_for(:employee).merge(
      country_id: create(:country).id, department_id: create(:department).id, level_id: create(:level).id
    )
  end

  it "creates the employee, audits it, and returns it" do
    employee = described_class.call(attributes)

    expect(employee).to be_persisted
    expect(employee.audits.sole.action).to eq("create")
  end

  it "raises on an invalid attribute" do
    expect { described_class.call(attributes.merge(email: "not an email")) }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it "writes no row and no audit when it raises" do
    expect { described_class.call(attributes.merge(email: "not an email")) }
      .to raise_error(ActiveRecord::RecordInvalid).and not_change { [ Employee.count, Audited::Audit.count ] }
  end
end
