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
class Country < ApplicationRecord
  audited

  has_many :employees, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.squish }

  # Names carry no unique index, so the code breaks a tie.
  scope :by_name, -> { order("lower(countries.name)", :code) }

  validates :code, presence: true, uniqueness: true, format: { with: /\A[A-Z]{2}\z/ }
  validates :name, presence: true
  validates :employer_cost_multiplier, presence: true, numericality: { greater_than: 0, less_than: 100 }
  validate :employer_cost_multiplier_fits_scale

  private
    # The decimal type rounds to the column's scale on cast, so a fifth place would save as a silent round.
    def employer_cost_multiplier_fits_scale
      value = BigDecimal(employer_cost_multiplier_before_type_cast.to_s, exception: false)
      return if value.nil? || value.round(4) == value

      errors.add(:employer_cost_multiplier, "must have at most 4 decimal places")
    end
end
