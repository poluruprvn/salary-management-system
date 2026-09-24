# == Schema Information
#
# Table name: salary_revisions
#
#  id             :uuid             not null, primary key
#  amount_cents   :bigint           not null
#  effective_date :date             not null
#  note           :text
#  reason         :string           not null
#  voided_at      :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  employee_id    :uuid             not null
#
# Indexes
#
#  index_salary_revisions_on_employee_id                          (employee_id)
#  index_salary_revisions_on_employee_id_and_live_effective_date  (employee_id,effective_date) UNIQUE WHERE (voided_at IS NULL)
#  index_salary_revisions_on_updated_at                           (updated_at)
#
# Foreign Keys
#
#  fk_rails_...  (employee_id => employees.id)
#
# Check Constraints
#
#  salary_revisions_amount_cents_positive  (amount_cents > 0)
#
class SalaryRevision < ApplicationRecord
  REASONS = %w[merit promotion market_adjustment correction].freeze

  belongs_to :employee

  scope :live, -> { where(voided_at: nil) }

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0, less_than: 1_000_000_000_000 }
  validates :reason, inclusion: { in: REASONS }
  validates :effective_date, presence: true
  validates :effective_date, uniqueness: { scope: :employee_id, conditions: -> { live } }, unless: :voided_at?
  validate :effective_date_within_employment, if: -> { effective_date_changed? || employee_id_changed? }

  private
    # Only on a move, never on every save. Shortening employment strands revisions outside the
    # window, and a stranded revision still has to be voidable.
    def effective_date_within_employment
      return if effective_date.blank? || employee.blank?

      if employee.hire_date && effective_date < employee.hire_date
        errors.add(:effective_date, "must be on or after the hire date")
      elsif employee.exit_date && effective_date > employee.exit_date
        errors.add(:effective_date, "must be on or before the exit date")
      end
    end
end
