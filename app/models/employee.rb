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

  # The exit date is inclusive: the register pays that day.
  scope :active_as_of, ->(date) { where("hire_date <= :date AND (exit_date IS NULL OR exit_date >= :date)", date: date) }
  scope :pending_as_of, ->(date) { where("hire_date > :date", date: date) }
  scope :exited_as_of, ->(date) { where("exit_date < :date", date: date) }

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
end
