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
FactoryBot.define do
  factory :country do
    sequence(:code) { |n| ("A".."Z").to_a.values_at(n / 26 % 26, n % 26).join }
    name { Faker::Address.country }
    employer_cost_multiplier { 1.2 }
  end
end
