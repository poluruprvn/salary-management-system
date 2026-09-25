require "rails_helper"

# == Schema Information
#
# Table name: countries
#
#  id                       :uuid             not null, primary key
#  code                     :string(2)        not null
#  employer_cost_multiplier :decimal(6, 4)    default(1.0), not null
#  name                     :string           not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#
# Indexes
#
#  index_countries_on_code  (code) UNIQUE
#
# Check Constraints
#
#  countries_code_format                        (code::text ~ '^[A-Z]{2}$'::text)
#  countries_employer_cost_multiplier_positive  (employer_cost_multiplier > 0::numeric)
#
RSpec.describe Country do
  it { is_expected.to have_many(:employees) }
  it { is_expected.to validate_presence_of(:name) }

  it "accepts a two letter uppercase code only" do
    expect(build(:country, code: "DE")).to be_valid
    expect(build(:country, code: "de")).not_to be_valid
    expect(build(:country, code: "DEU")).not_to be_valid
  end

  it "rejects a duplicate code" do
    create(:country, code: "DE")

    expect(build(:country, code: "DE")).not_to be_valid
  end

  it "rejects a multiplier of zero or less" do
    expect(build(:country, employer_cost_multiplier: 0)).not_to be_valid
    expect(build(:country, employer_cost_multiplier: -1)).not_to be_valid
  end

  it "rejects a multiplier the decimal column cannot hold" do
    expect(build(:country, employer_cost_multiplier: 100)).not_to be_valid
  end

  it "rejects a multiplier with a fifth decimal place rather than rounding it" do
    expect(build(:country, employer_cost_multiplier: "1.4567")).to be_valid
    expect(build(:country, employer_cost_multiplier: "1.45678")).not_to be_valid
  end

  it "holds the multiplier in a check constraint when the validation is skipped" do
    country = build(:country, employer_cost_multiplier: 0)

    expect { country.save!(validate: false) }.to raise_error(ActiveRecord::CheckViolation)
  end

  it "refuses to destroy a country with employees" do
    employee = create(:employee)

    expect(employee.country.destroy).to be(false)
    expect(employee.country.errors[:base]).to be_present
  end
end
