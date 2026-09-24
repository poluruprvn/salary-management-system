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
FactoryBot.define do
  factory :level do
    sequence(:code) { |n| "L#{n}" }
    sequence(:rank) { |n| n }
    name { "Level #{rank}" }
  end
end
