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
class Level < ApplicationRecord
  has_many :employees, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.squish }
  normalizes :code, with: ->(code) { code.strip }

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :rank, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than: 0, less_than: 2_147_483_648 }
end
