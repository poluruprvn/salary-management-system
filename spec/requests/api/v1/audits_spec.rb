require 'swagger_helper'

RSpec.describe "Audits" do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{AccessToken.encode(user)}" }
  let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }

  path "/api/v1/employees/{employee_id}/audits" do
    parameter name: :employee_id, in: :path, schema: { type: :string, format: :uuid }

    let(:employee_id) { employee.id }

    get "List who changed an employee, and their salary revisions, and when" do
      tags "Audits"
      produces "application/json"
      description "Newest first. Covers the employee's own changes and every change to their salary revisions."
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1, default: 1 }
      parameter name: :per_page, in: :query, required: false, schema: { type: :integer, minimum: 1, default: 25 },
                description: "Above 100 is clamped to 100, not refused"

      response "200", "a page of the trail" do
        schema type: :object, required: %w[data pagination], properties: {
          data: { type: :array, items: { "$ref" => "#/components/schemas/audit" } },
          pagination: { "$ref" => "#/components/schemas/pagination" }
        }
        before do
          Audited::Audit.as_user(user) do
            create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1))
          end
        end
        run_test!
      end

      response "404", "no employee has that id" do
        schema "$ref" => "#/components/schemas/error"
        let(:employee_id) { SecureRandom.uuid }
        run_test!
      end

      response "422", "page or per_page is not a positive integer" do
        schema "$ref" => "#/components/schemas/error"
        let(:page) { 0 }
        run_test!
      end

      requires_a_token
    end
  end

  describe "GET /api/v1/employees/:employee_id/audits" do
    def trail(params = {})
      get "/api/v1/employees/#{employee.id}/audits", params: params, headers: bearer_headers(user)
      response.parsed_body
    end

    # Phase 3 could not assert this: without a controller there is no actor.
    it "names the signed in user who made each change" do
      patch "/api/v1/employees/#{employee.id}", params: { title: "Staff Engineer" }, headers: bearer_headers(user), as: :json
      post "/api/v1/employees/#{employee.id}/salary_revisions",
           params: { amount_cents: 12_000_000, effective_date: "2024-01-01", reason: "merit" },
           headers: bearer_headers(user), as: :json
      revision_id = response.parsed_body["id"]

      expect(trail["data"].map { |row| row.slice("action", "auditable_type", "auditable_id", "user") }).to eq([
        { "action" => "create", "auditable_type" => "salary_revision", "auditable_id" => revision_id,
          "user" => { "id" => user.id, "name" => user.name, "email" => user.email } },
        { "action" => "update", "auditable_type" => "employee", "auditable_id" => employee.id,
          "user" => { "id" => user.id, "name" => user.name, "email" => user.email } },
        { "action" => "create", "auditable_type" => "employee", "auditable_id" => employee.id, "user" => nil }
      ])
      expect(trail["data"].second["audited_changes"]).to eq("title" => [ "Engineer", "Staff Engineer" ])
    end

    it "leaves out other employees' changes" do
      create(:salary_revision, employee: create(:employee, hire_date: Date.new(2024, 1, 1)))

      expect(trail["data"].pluck("auditable_id")).to eq([ employee.id ])
    end

    it "pages through the pagination envelope" do
      [ "Senior Engineer", "Staff Engineer", "Principal Engineer" ].each { |title| employee.update!(title: title) }

      body = trail(per_page: 3, page: 2)

      expect(body["data"].pluck("action")).to eq(%w[create])
      expect(body["pagination"]).to include("total" => 4, "page" => 2, "prev_page" => 1, "next_page" => nil)
    end
  end
end
