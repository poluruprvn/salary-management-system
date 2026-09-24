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

  # lower() because postgres:18-alpine is musl, which collates bytewise and puts every capital
  # first. level sorts by rank, since as text L10 sorts before L2. exit_date and salary can be
  # null, and Postgres puts nulls first on DESC.
  SORT_KEYS = {
    "name" => { expression: Arel.sql("lower(employees.name)") },
    "hire_date" => { expression: Arel.sql("employees.hire_date") },
    "exit_date" => { expression: Arel.sql("employees.exit_date"), nulls_last: true },
    "salary" => { expression: Arel.sql("current_salary.amount_cents"), nulls_last: true },
    "department" => { expression: Arel.sql("lower(departments.name)"), joins: :department },
    "country" => { expression: Arel.sql("lower(countries.name)"), joins: :country },
    "level" => { expression: Arel.sql("levels.rank"), joins: :level }
  }.freeze

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

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :title, presence: true
  validates :hire_date, presence: true
  validate :exit_date_not_before_hire_date
  validate :hire_date_not_after_live_revisions, if: -> { persisted? && hire_date_changed? }

  # The exit date is inclusive: the register pays that day.
  scope :active_as_of, ->(date) { where("hire_date <= :date AND (exit_date IS NULL OR exit_date >= :date)", date: date) }
  scope :pending_as_of, ->(date) { where("hire_date > :date", date: date) }
  scope :exited_as_of, ->(date) { where("exit_date < :date", date: date) }

  # Filters only. No join and no order, so the page count never pays for the salary lookup.
  def self.filtered(filters, as_of:)
    relation = all
    relation = relation.search(filters[:q]) if filters[:q].present?
    relation = relation.where(title: filters[:title]) if filters[:title].present?
    relation = relation.with_status(filters[:status].to_s, as_of: as_of) if filters[:status].present?

    %i[department_id country_id level_id].each do |key|
      ids = Array(filters[key]).compact_blank
      relation = relation.where(key => ids) if ids.any?
    end

    relation
  end

  # ILIKE has no operator for uuid, so an id is an exact match instead. Nobody types part of one.
  def self.search(term)
    term = term.to_s.squish

    if (id = type_for_attribute(:id).cast(term))
      where(id: id)
    else
      where("employees.name ILIKE :pattern OR employees.email ILIKE :pattern OR employees.title ILIKE :pattern",
            pattern: "%#{sanitize_sql_like(term)}%")
    end
  end

  def self.with_status(status, as_of:)
    raise InvalidParameter.new(:status, "must be one of #{STATUSES.join(", ")}") unless STATUSES.include?(status)

    public_send("#{status}_as_of", as_of)
  end

  def self.with_salary_as_of(date)
    joins(sanitize_sql_array([ SALARY_AS_OF_JOIN, { as_of: date } ]))
      .select(arel_table[Arel.star],
              "current_salary.amount_cents AS current_salary_amount_cents",
              "current_salary.effective_date AS current_salary_effective_date")
  end

  # Sorting by salary reads the lateral, so it needs with_salary_as_of on the same relation.
  def self.sorted_by(sort)
    sort = sort.to_s.presence || "name"
    key = SORT_KEYS.fetch(sort.delete_prefix("-")) { raise UnknownSortKey, sort }
    order = sort.start_with?("-") ? key[:expression].desc : key[:expression].asc
    order = order.nulls_last if key[:nulls_last]

    relation = key[:joins] ? joins(key[:joins]) : all
    # Every key has ties, so the id tiebreak fixes their order and offset pages never repeat or
    # skip a row.
    relation.order(order, :id)
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

  private
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
