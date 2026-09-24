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
class Department < ApplicationRecord
  has_many :employees, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.squish }

  scope :by_name, -> { order("lower(departments.name)") }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
