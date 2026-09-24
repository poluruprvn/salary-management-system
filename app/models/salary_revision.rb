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

  PREVIOUS_AMOUNT = <<~SQL.squish
    LAG(salary_revisions.amount_cents) OVER (
      PARTITION BY salary_revisions.employee_id
      ORDER BY salary_revisions.effective_date, salary_revisions.id
    ) AS previous_amount_cents
  SQL

  audited associated_with: :employee

  belongs_to :employee

  attribute :effective_date, StrictDateType.new

  scope :live, -> { where(voided_at: nil) }
  # WHERE runs before the window, so a voided revision is never anyone's previous amount. A chained
  # where or find also runs first and hides rows from LAG, so page this with limit and offset only.
  scope :history_for, ->(employee) do
    live.where(employee: employee).select("salary_revisions.*", PREVIOUS_AMOUNT).order(effective_date: :desc, id: :desc)
  end

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0, less_than: 1_000_000_000_000 }
  validates :reason, inclusion: { in: REASONS }
  validates :effective_date, presence: true
  validates :effective_date, uniqueness: { scope: :employee_id, conditions: -> { live } }, unless: :voided_at?
  validate :effective_date_within_employment, if: -> { effective_date_changed? || employee_id_changed? || unvoiding? }
  validate :unchanged_while_voided, if: -> { voided_at_in_database && changed? && !voided_at_changed? }

  private
    def unvoiding?
      voided_at_changed? && voided_at.nil?
    end

    # Every read skips a voided row, so an edit to one would succeed and change nothing anyone sees.
    def unchanged_while_voided
      errors.add(:base, "A voided revision cannot be edited")
    end

    # Only on a move or an un-void, never on every save. Shortening employment strands revisions
    # outside the window, and a stranded revision still has to be voidable. Putting one back into
    # the live set is a different act, so that one is checked.
    def effective_date_within_employment
      return if effective_date.blank? || employee.blank?

      if employee.hire_date && effective_date < employee.hire_date
        errors.add(:effective_date, "must be on or after the hire date")
      elsif employee.exit_date && effective_date > employee.exit_date
        errors.add(:effective_date, "must be on or before the exit date")
      end
    end
end
