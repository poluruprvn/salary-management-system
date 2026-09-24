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
FactoryBot.define do
  factory :salary_revision do
    employee
    amount_cents { 12_000_000 }
    effective_date { employee&.hire_date }
    reason { "merit" }

    trait :voided do
      voided_at { Time.current }
    end
  end
end
