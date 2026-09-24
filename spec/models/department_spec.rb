require "rails_helper"

# == Schema Information
#
# Table name: departments
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_departments_on_lower_name  (lower((name)::text)) UNIQUE
#
RSpec.describe Department do
  it { is_expected.to have_many(:employees) }
  it { is_expected.to validate_presence_of(:name) }

  it "rejects a name already taken in a different case" do
    create(:department, name: "Engineering")

    expect(build(:department, name: "engineering")).not_to be_valid
  end

  it "squishes the name, so surrounding space is not a second department" do
    create(:department, name: "Engineering")
    duplicate = build(:department, name: "  engineering  ")

    expect(duplicate).not_to be_valid
    expect(build(:department, name: " Data  Science ").tap(&:valid?).name).to eq("Data Science")
  end

  it "rejects it in the index too when the validation is skipped" do
    create(:department, name: "Engineering")
    duplicate = build(:department, name: "engineering")

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
