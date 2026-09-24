require "rails_helper"

# == Schema Information
#
# Table name: levels
#
#  id         :uuid             not null, primary key
#  code       :string           not null
#  name       :string           not null
#  rank       :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_levels_on_lower_code  (lower((code)::text)) UNIQUE
#  index_levels_on_rank        (rank) UNIQUE
#
RSpec.describe Level do
  it { is_expected.to have_many(:employees) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:rank) }

  it "rejects a code already taken in a different case" do
    create(:level, code: "L2")

    expect(build(:level, code: "l2")).not_to be_valid
  end

  it "strips the code, so surrounding space is not a second level" do
    create(:level, code: "L2")

    expect(build(:level, code: " l2 ")).not_to be_valid
  end

  it "rejects a duplicate rank" do
    create(:level, rank: 30)

    expect(build(:level, rank: 30)).not_to be_valid
  end

  it "rejects a rank the integer column cannot hold" do
    expect(build(:level, rank: 3_000_000_000)).not_to be_valid
    expect(build(:level, rank: 0)).not_to be_valid
  end

  it "rejects a duplicate code in the index too when the validation is skipped" do
    create(:level, code: "L2")
    duplicate = build(:level, code: "l2")

    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
