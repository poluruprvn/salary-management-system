# == Schema Information
#
# Table name: employees
#
#  id            :uuid             not null, primary key
#  email         :string           not null
#  exit_date     :date
#  hire_date     :date             not null
#  name          :string           not null
#  title         :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  country_id    :uuid             not null
#  department_id :uuid             not null
#  level_id      :uuid             not null
#
# Indexes
#
#  index_employees_on_country_id         (country_id)
#  index_employees_on_department_id      (department_id)
#  index_employees_on_exit_date          (exit_date)
#  index_employees_on_hire_date          (hire_date)
#  index_employees_on_level_id           (level_id)
#  index_employees_on_lower_email        (lower((email)::text)) UNIQUE
#  index_employees_on_lower_name_and_id  (lower((name)::text), id)
#  index_employees_on_title              (title)
#  index_employees_on_updated_at         (updated_at)
#
# Foreign Keys
#
#  fk_rails_...  (country_id => countries.id)
#  fk_rails_...  (department_id => departments.id)
#  fk_rails_...  (level_id => levels.id)
#
# Check Constraints
#
#  employees_exit_date_not_before_hire_date  (exit_date IS NULL OR exit_date >= hire_date)
#
class Employee < ApplicationRecord
  STATUSES = %w[pending active exited].freeze

  # No sr.id tiebreak. The partial unique index allows at most one live row per date, but the
  # planner cannot prove it and would add an Incremental Sort per employee on top of the
  # backward index scan.
  SALARY_AS_OF_JOIN = <<~SQL.squish
    LEFT JOIN LATERAL (
      SELECT sr.amount_cents, sr.effective_date
      FROM salary_revisions sr
      WHERE sr.employee_id = employees.id
        AND sr.effective_date <= :as_of
        AND sr.voided_at IS NULL
        AND employees.hire_date <= :as_of
        AND (employees.exit_date IS NULL OR employees.exit_date >= :as_of)
      ORDER BY sr.effective_date DESC
      LIMIT 1
    ) current_salary ON TRUE
  SQL

  audited
  has_associated_audits

  belongs_to :country
  belongs_to :department
  belongs_to :level

  has_many :salary_revisions, dependent: :restrict_with_error

  normalizes :name, with: ->(name) { name.squish }
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :title, with: ->(title) { title.squish }

  attribute :hire_date, StrictDateType.new
  attribute :exit_date, StrictDateType.new

  # Each is indexed, and a value past a few thousand bytes no longer fits a btree entry: a 500.
  validates :name, presence: true, length: { maximum: 255 }
  validates :email, presence: true, length: { maximum: 255 }, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :title, presence: true, length: { maximum: 255 }
  validates :hire_date, presence: true
  validate :exit_date_is_a_date
  validate :exit_date_not_before_hire_date
  validate :hire_date_not_after_live_revisions, if: -> { persisted? && hire_date_changed? }

  # The exit date is inclusive: the register pays that day.
  scope :active_as_of, ->(date) { where(hire_date: ..date, exit_date: [ nil, date.. ]) }
  scope :pending_as_of, ->(date) { where.not(hire_date: ..date) }
  scope :exited_as_of, ->(date) { where(exit_date: ...date) }

  scope :joins_salary_as_of, ->(date) { joins(sanitize_sql_array([ SALARY_AS_OF_JOIN, { as_of: date } ])) }

  def self.with_salary_as_of(date)
    joins_salary_as_of(date)
      .select("employees.*",
              "current_salary.amount_cents AS current_salary_amount_cents",
              "current_salary.effective_date AS current_salary_effective_date")
  end

  # Every employee ever, not an as_of set. The count ranks the spelling most people already use first.
  def self.title_counts(term)
    relation = group(:title).select(:title, "COUNT(*) AS employee_count")
      .order("employee_count DESC", "lower(employees.title)", :title)
    term = term.to_s.squish
    return relation if term.empty?

    relation.where("employees.title ILIKE ?", "%#{sanitize_sql_like(term)}%")
  end

  def status_as_of(date = Date.current)
    return "pending" if hire_date > date
    return "exited" if exit_date && exit_date < date

    "active"
  end

  # Only an active day has a salary. The list path reads the same answer through a lateral join,
  # which has to carry the same employment window.
  def salary_as_of(date = Date.current)
    return unless status_as_of(date) == "active"

    salary_revisions.live.where(effective_date: ..date).order(effective_date: :desc).first
  end

  # The employee's own changes and their revisions', newest first. The gem orders on created_at
  # alone, which can tie, and offset pages need the id to break it.
  def audit_trail
    own_and_associated_audits.order(id: :desc)
  end

  private
    # A value that is not a date casts to nil, which on this column would clear the exit date. Only
    # null and an empty string mean no exit date.
    def exit_date_is_a_date
      return if exit_date || exit_date_before_type_cast.in?([ nil, "" ])

      errors.add(:exit_date, "is not a valid date")
    end

    def exit_date_not_before_hire_date
      return if exit_date.blank? || hire_date.blank?

      errors.add(:exit_date, "must be on or after the hire date") if exit_date < hire_date
    end

    # A revision before the hire date still answers salary_as_of, so it would pay for a day the
    # employee was not employed. Shortening the exit date stays permissive: a revision stranded
    # that way is already invisible to every read, and voiding it is the retraction path.
    def hire_date_not_after_live_revisions
      return if hire_date.blank?
      return unless salary_revisions.live.exists?(effective_date: ...hire_date)

      errors.add(:hire_date, "must be on or before the earliest revision on file")
    end
end
