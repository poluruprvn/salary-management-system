require 'rails_helper'

uuid = { type: :string, format: :uuid }
date = { type: :string, format: :date }
timestamp = { type: :string, format: "date-time" }
cents = { type: :integer, format: :int64, description: "Minor units of the base currency" }
user = {
  type: :object,
  required: %w[id name email],
  properties: { id: uuid, name: { type: :string }, email: { type: :string, format: :email } }
}
salary_revision = {
  id: uuid,
  amount_cents: cents,
  effective_date: date,
  reason: { type: :string, enum: SalaryRevision::REASONS },
  note: { type: :string, nullable: true },
  voided_at: timestamp.merge(nullable: true)
}
previous_amount_cents = cents.merge(nullable: true, description: "The live amount in force the day before, null for the first revision")

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/openapi.yaml" => {
      openapi: "3.0.1",
      info: { title: "Salary Management API", version: "v1" },
      servers: [ { url: "http://localhost:3000" } ],
      paths: {},
      components: {
        securitySchemes: {
          bearer_auth: { type: :http, scheme: :bearer, bearerFormat: "JWT" }
        },
        schemas: {
          token_pair: {
            type: :object,
            required: %w[access_token expires_in refresh_token],
            properties: {
              access_token: { type: :string },
              expires_in: { type: :integer, description: "Seconds the access token stays valid" },
              refresh_token: { type: :string }
            }
          },
          error: {
            type: :object,
            required: %w[error],
            properties: {
              error: {
                type: :object,
                required: %w[code message details],
                properties: {
                  code: { type: :string },
                  message: { type: :string },
                  details: {
                    type: :array,
                    items: {
                      type: :object,
                      required: %w[field message],
                      properties: { field: { type: :string }, message: { type: :string } }
                    }
                  }
                }
              }
            }
          },
          pagination: {
            type: :object,
            required: %w[total page per_page total_pages prev_page next_page],
            properties: {
              total: { type: :integer },
              page: { type: :integer },
              per_page: { type: :integer, description: "The page size used, after clamping to 100" },
              total_pages: { type: :integer },
              prev_page: {
                type: :integer, nullable: true,
                description: "Null on the first page. Past the end it is the last real page."
              },
              next_page: { type: :integer, nullable: true, description: "Null on the last page" }
            }
          },
          user: user,
          meta: {
            type: :object,
            required: %w[base_currency minor_unit today employee_statuses salary_revision_reasons],
            properties: {
              base_currency: { type: :string, example: "USD" },
              minor_unit: { type: :integer, description: "Decimal places in an amount: amount_cents / 10^minor_unit" },
              today: date.merge(description: "The as_of a request gets when it omits the parameter"),
              employee_statuses: { type: :array, items: { type: :string } },
              salary_revision_reasons: { type: :array, items: { type: :string } }
            }
          },
          country: {
            type: :object,
            required: %w[id code name employer_cost_multiplier],
            properties: {
              id: uuid,
              code: { type: :string, example: "IN" },
              name: { type: :string },
              employer_cost_multiplier: {
                type: :string, example: "1.45",
                description: "A decimal string, so the client never holds it as a float. Gross times this is fully loaded."
              }
            }
          },
          department: {
            type: :object,
            required: %w[id name],
            properties: { id: uuid, name: { type: :string } }
          },
          level: {
            type: :object,
            required: %w[id code name rank],
            properties: {
              id: uuid, code: { type: :string, example: "L4" }, name: { type: :string },
              rank: { type: :integer, description: "Orders levels. Sort on this, never on the code." }
            }
          },
          employee: {
            type: :object,
            required: %w[id name email title hire_date exit_date status as_of country department level current_salary],
            properties: {
              id: uuid,
              name: { type: :string },
              email: { type: :string, format: :email },
              title: { type: :string },
              hire_date: date,
              exit_date: date.merge(nullable: true, description: "Inclusive: the employee is active and paid that day"),
              status: { type: :string, enum: Employee::STATUSES, description: "Derived from the dates, as of as_of" },
              as_of: date.merge(description: "The date status and current_salary were computed for"),
              country: { "$ref" => "#/components/schemas/country" },
              department: { "$ref" => "#/components/schemas/department" },
              level: { "$ref" => "#/components/schemas/level" },
              current_salary: {
                type: :object, nullable: true,
                description: "The live revision in force on as_of. Null unless the employee is active that day.",
                required: %w[amount_cents effective_date],
                properties: { amount_cents: cents, effective_date: date }
              }
            }
          },
          salary_revision: {
            type: :object,
            required: salary_revision.keys.map(&:to_s),
            properties: salary_revision
          },
          salary_history_entry: {
            type: :object,
            required: salary_revision.keys.map(&:to_s) + %w[previous_amount_cents],
            properties: salary_revision.merge(previous_amount_cents: previous_amount_cents)
          },
          salary_change: {
            type: :object,
            required: salary_revision.keys.map(&:to_s) + %w[previous_amount_cents previous_effective_date],
            properties: salary_revision.merge(
              previous_amount_cents: previous_amount_cents,
              previous_effective_date: date.merge(nullable: true)
            )
          },
          audit: {
            type: :object,
            required: %w[id action auditable_type auditable_id audited_changes user created_at],
            properties: {
              id: uuid,
              action: { type: :string, enum: %w[create update destroy] },
              auditable_type: { type: :string, enum: %w[employee salary_revision] },
              auditable_id: uuid,
              audited_changes: {
                type: :object, additionalProperties: true,
                description: "On create, each attribute's value. On update, each changed attribute as [old, new]."
              },
              user: user.merge(nullable: true, description: "Who made the change. Null outside a signed in request."),
              created_at: timestamp
            }
          },
          title_count: {
            type: :object,
            required: %w[title employee_count],
            properties: { title: { type: :string }, employee_count: { type: :integer } }
          }
        }
      },
      security: [ { bearer_auth: [] } ]
    }
  }

  config.openapi_format = :yaml
  # A response that does not match its declared schema fails the example rather than documenting a lie.
  config.openapi_strict_schema_validation = true
end
