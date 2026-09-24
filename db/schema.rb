# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_24_094756) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audits", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "action", null: false
    t.uuid "associated_id"
    t.string "associated_type"
    t.uuid "auditable_id", null: false
    t.string "auditable_type", null: false
    t.jsonb "audited_changes"
    t.string "comment"
    t.datetime "created_at", null: false
    t.string "remote_address"
    t.string "request_uuid"
    t.uuid "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0, null: false
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "countries", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "code", limit: 2, null: false
    t.datetime "created_at", null: false
    t.decimal "employer_cost_multiplier", precision: 6, scale: 4, default: "1.0", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_countries_on_code", unique: true
    t.check_constraint "code::text ~ '^[A-Z]{2}$'::text", name: "countries_code_format"
    t.check_constraint "employer_cost_multiplier > 0::numeric", name: "countries_employer_cost_multiplier_positive"
  end

  create_table "departments", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_departments_on_lower_name", unique: true
  end

  create_table "employees", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "country_id", null: false
    t.datetime "created_at", null: false
    t.uuid "department_id", null: false
    t.string "email", null: false
    t.date "exit_date"
    t.date "hire_date", null: false
    t.uuid "level_id", null: false
    t.string "name", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_employees_on_lower_email", unique: true
    t.index "lower((name)::text), id", name: "index_employees_on_lower_name_and_id"
    t.index ["country_id"], name: "index_employees_on_country_id"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["exit_date"], name: "index_employees_on_exit_date"
    t.index ["hire_date"], name: "index_employees_on_hire_date"
    t.index ["level_id"], name: "index_employees_on_level_id"
    t.index ["title"], name: "index_employees_on_title"
    t.index ["updated_at"], name: "index_employees_on_updated_at"
    t.check_constraint "exit_date IS NULL OR exit_date >= hire_date", name: "employees_exit_date_not_before_hire_date"
  end

  create_table "levels", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "rank", null: false
    t.datetime "updated_at", null: false
    t.index "lower((code)::text)", name: "index_levels_on_lower_code", unique: true
    t.index ["rank"], name: "index_levels_on_rank", unique: true
  end

  create_table "refresh_tokens", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["expires_at"], name: "index_refresh_tokens_on_expires_at"
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "salary_revisions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.date "effective_date", null: false
    t.uuid "employee_id", null: false
    t.text "note"
    t.string "reason", null: false
    t.datetime "updated_at", null: false
    t.datetime "voided_at"
    t.index ["employee_id", "effective_date"], name: "index_salary_revisions_on_employee_id_and_live_effective_date", unique: true, where: "(voided_at IS NULL)"
    t.index ["employee_id"], name: "index_salary_revisions_on_employee_id"
    t.index ["updated_at"], name: "index_salary_revisions_on_updated_at"
    t.check_constraint "amount_cents > 0", name: "salary_revisions_amount_cents_positive"
  end

  create_table "users", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
  end

  add_foreign_key "employees", "countries"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "levels"
  add_foreign_key "refresh_tokens", "users", on_delete: :cascade
  add_foreign_key "salary_revisions", "employees"
end
