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
FactoryBot.define do
  factory :department do
    sequence(:name) { |n| "Department #{n}" }
  end
end
