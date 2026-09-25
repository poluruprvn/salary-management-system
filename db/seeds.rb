# Production does not load Faker, and invented employees do not belong there. The container's
# db:prepare seeds an empty database, so this returns rather than aborts: abort raises SystemExit,
# which fails db:prepare and stops the first boot.
return unless Rails.env.local?

# weight is a share of headcount. pay scales a level's US base salary. The multiplier is a rough
# figure for statutory employer contributions on top of gross.
countries = [
  { code: "US", name: "United States", employer_cost_multiplier: 1.08, locale: "en-US", pay: 1.0, weight: 28 },
  { code: "CA", name: "Canada", employer_cost_multiplier: 1.08, locale: "en-CA", pay: 0.78, weight: 7 },
  { code: "BR", name: "Brazil", employer_cost_multiplier: 1.36, locale: "pt-BR", pay: 0.32, weight: 6 },
  { code: "GB", name: "United Kingdom", employer_cost_multiplier: 1.15, locale: "en-GB", pay: 0.72, weight: 10 },
  { code: "DE", name: "Germany", employer_cost_multiplier: 1.21, locale: "de", pay: 0.7, weight: 9 },
  { code: "FR", name: "France", employer_cost_multiplier: 1.45, locale: "fr", pay: 0.55, weight: 7 },
  { code: "ES", name: "Spain", employer_cost_multiplier: 1.31, locale: "es", pay: 0.4, weight: 6 },
  { code: "PL", name: "Poland", employer_cost_multiplier: 1.21, locale: "pl", pay: 0.44, weight: 7 },
  { code: "IN", name: "India", employer_cost_multiplier: 1.05, locale: "en-IND", pay: 0.24, weight: 20 }
]

departments = [
  { name: "Engineering", pay: 1.1, weight: 30,
    roles: [ "Software Engineer", "Backend Engineer", "Frontend Engineer", "Mobile Engineer", "Site Reliability Engineer", "QA Engineer" ] },
  { name: "Data", pay: 1.08, weight: 7, roles: [ "Data Analyst", "Data Engineer", "Data Scientist", "Machine Learning Engineer" ] },
  { name: "Product", pay: 1.1, weight: 6, roles: [ "Product Manager", "Technical Product Manager", "Product Analyst" ] },
  { name: "Design", pay: 1.0, weight: 5, roles: [ "Product Designer", "UX Researcher", "Brand Designer" ] },
  { name: "Sales", pay: 0.95, weight: 14,
    roles: [ "Account Executive", "Sales Development Representative", "Solutions Engineer", "Account Manager" ] },
  { name: "Marketing", pay: 0.95, weight: 8,
    roles: [ "Marketing Manager", "Content Strategist", "Growth Marketer", "Product Marketing Manager" ] },
  { name: "Customer Success", pay: 0.82, weight: 14, roles: [ "Customer Success Manager", "Support Specialist", "Implementation Consultant" ] },
  { name: "Finance", pay: 1.0, weight: 8, roles: [ "Accountant", "Financial Analyst", "Payroll Specialist" ] },
  { name: "People", pay: 0.92, weight: 8,
    roles: [ "HR Business Partner", "Recruiter", "People Operations Specialist", "Compensation Analyst" ] }
]

# L6 and L7 manage, so their titles name the department instead of a role.
levels = [
  { code: "L1", name: "Associate", rank: 1, base: 70_000, weight: 150, title: "Associate %{role}" },
  { code: "L2", name: "Intermediate", rank: 2, base: 90_000, weight: 260, title: "%{role}" },
  { code: "L3", name: "Senior", rank: 3, base: 118_000, weight: 270, title: "Senior %{role}" },
  { code: "L4", name: "Lead", rank: 4, base: 150_000, weight: 180, title: "Lead %{role}" },
  { code: "L5", name: "Principal", rank: 5, base: 185_000, weight: 107, title: "Principal %{role}" },
  { code: "L6", name: "Director", rank: 6, base: 230_000, weight: 28, title: "Director of %{department}" },
  { code: "L7", name: "Vice President", rank: 7, base: 290_000, weight: 5, title: "VP of %{department}" }
]

raises = [
  { reason: "merit", weight: 70, increase: 0.03..0.07 },
  { reason: "promotion", weight: 15, increase: 0.08..0.15 },
  { reason: "market_adjustment", weight: 15, increase: 0.04..0.1 }
]

pick = ->(random, options) do
  target = random.rand(options.sum { |option| option[:weight] })
  options.find { |option| (target -= option[:weight]).negative? }
end

count = Integer(ENV.fetch("SEED_EMPLOYEE_COUNT", 10_000))

begin
  ApplicationRecord.transaction do
    User.create_with(name: "HR Manager", password: ENV.fetch("SEED_HR_PASSWORD", "password"))
      .find_or_create_by!(email: ENV.fetch("SEED_HR_EMAIL", "hr@example.com"))

    # Seeded rows have no actor, and the employees skip auditing through insert_all.
    Country.without_auditing do
      countries.each do |country|
        country[:id] = Country.create_with(country.slice(:name, :employer_cost_multiplier)).find_or_create_by!(code: country[:code]).id
      end
    end
    departments.each { |department| department[:id] = Department.find_or_create_by!(name: department[:name]).id }
    levels.each { |level| level[:id] = Level.create_with(level.slice(:name, :rank)).find_or_create_by!(code: level[:code]).id }

    today = Date.current
    handles = Hash.new(0)
    employees = []
    revisions = []

    count.times do |index|
      # A generator per employee, so a change to one employee's draws leaves the others' draws alone.
      random = Random.new(index)
      Faker::Config.random = random

      country = pick.(random, countries)
      department = pick.(random, departments)
      level = pick.(random, levels)
      title = format(level[:title], role: department[:roles].sample(random: random), department: department[:name])

      name = Faker::Base.with_locale(country[:locale]) { "#{Faker::Name.first_name} #{Faker::Name.last_name}" }.squish
      # Faker repeats names. Without the counter, ON CONFLICT DO NOTHING would silently drop the
      # second of two equal emails.
      handle = name.parameterize(separator: ".")
      handles[handle] += 1
      email = "#{handle}#{handles[handle] if handles[handle] > 1}@example.com"

      pending = random.rand < 0.01
      hire_date = pending ? today + random.rand(1..90) : today - random.rand(0..(8 * 365))
      # A leaver stays at least 90 days, and a few leave in the next two months.
      leaves = !pending && hire_date <= today - 30 && random.rand < 0.08
      exit_date = hire_date + random.rand(90..(today + 60 - hire_date).to_i) if leaves

      raise_dates = []
      date = hire_date
      4.times do
        date = (date + random.rand(12..18).months).beginning_of_month
        break if date > [ today, exit_date ].compact.min

        raise_dates << date
      end
      # Approved and not yet in force, so moving as_of forward changes the answer.
      raise_dates << (today + random.rand(1..6).months).beginning_of_month if !pending && !exit_date && random.rand < 0.03

      # No reason names a hire, so the note says what the first revision is.
      dollars = (level[:base] * country[:pay] * department[:pay] * random.rand(0.85..1.15)).round(-2)
      revisions << [ email, { effective_date: hire_date, amount_cents: dollars * 100, reason: "market_adjustment", note: "Starting salary" } ]
      raise_dates.each do |effective_date|
        kind = pick.(random, raises)
        dollars = (dollars * (1 + random.rand(kind[:increase]))).round(-2)
        revisions << [ email, { effective_date: effective_date, amount_cents: dollars * 100, reason: kind[:reason], note: nil } ]
      end

      employees << {
        name: name, email: email, title: title, hire_date: hire_date, exit_date: exit_date,
        country_id: country[:id], department_id: department[:id], level_id: level[:id]
      }
    end

    # Only employees this run inserted get revisions. On an existing employee a seeded revision
    # could come back after it was voided, or fall outside dates HR has since changed.
    employee_ids = {}
    employees.each_slice(2_000) do |batch|
      employee_ids.merge!(Employee.insert_all(batch, unique_by: :index_employees_on_lower_email, returning: %w[email id]).rows.to_h)
    end

    rows = revisions.filter_map { |email, revision| revision.merge(employee_id: employee_ids[email]) if employee_ids.key?(email) }
    rows.each_slice(2_000) do |batch|
      SalaryRevision.insert_all(batch, unique_by: :index_salary_revisions_on_employee_id_and_live_effective_date, returning: false)
    end
  end
ensure
  Faker::Config.random = nil
end
