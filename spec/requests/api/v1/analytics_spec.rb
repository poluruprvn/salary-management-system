require 'swagger_helper'

RSpec.describe "Analytics" do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{AccessToken.encode(user)}" }

  cents = { type: :integer, format: :int64, description: "Minor units of the base currency" }
  amounts = {
    headcount: { type: :integer, description: "Active employees on as_of" },
    salaried: { type: :integer, description: "Of those, how many have a salary in force. The rest are not in the amounts." },
    gross_cents: cents.merge(description: "Annual salary in force on as_of"),
    loaded_cents: cents.merge(description: "Gross times the country's current multiplier, rounded per employee")
  }
  amounts_schema = { type: :object, required: amounts.keys.map(&:to_s), properties: amounts }
  as_of_parameter = {
    name: :as_of, in: :query, required: false, schema: { type: :string, format: :date },
    description: "Defaults to today, and is echoed back"
  }

  path "/api/v1/analytics/run_rate" do
    get "Annual run rate by group" do
      tags "Analytics"
      produces "application/json"
      description "Active employees on as_of, grouped. A group with nobody active is left out. Rows are costliest first on loaded."
      parameter name: :group_by, in: :query, required: false,
                schema: { type: :string, enum: Employee::GROUP_KEYS.keys, default: "department" }
      parameter as_of_parameter

      response "200", "the run rate" do
        schema type: :object, required: %w[as_of group_by data totals], properties: {
          as_of: { type: :string, format: :date },
          group_by: { type: :string, enum: Employee::GROUP_KEYS.keys },
          data: {
            type: :array,
            items: {
              type: :object,
              required: %w[group] + amounts.keys.map(&:to_s),
              properties: {
                group: {
                  type: :object, required: %w[id name],
                  properties: { id: { type: :string, format: :uuid }, name: { type: :string } }
                },
                **amounts
              }
            }
          },
          totals: amounts_schema
        }

        before { create(:salary_revision) }

        run_test!
      end

      response "422", "group_by or as_of is invalid" do
        schema "$ref" => "#/components/schemas/error"
        let(:group_by) { "title" }
        run_test!
      end

      requires_a_token
    end
  end

  describe "GET /api/v1/analytics/run_rate" do
    let(:as_of) { Date.new(2024, 6, 1) }
    let(:engineering) { create(:department, name: "Engineering") }

    def run_rate(**params)
      get "/api/v1/analytics/run_rate", params: { as_of: as_of.iso8601, **params }, headers: bearer_headers(user)
      response.parsed_body
    end

    before do
      paid = create(:employee, department: engineering, hire_date: Date.new(2024, 1, 1))
      create(:salary_revision, employee: paid, amount_cents: 10_000_000)
      create(:employee, department: engineering, hire_date: Date.new(2024, 1, 1))
      create(:employee, hire_date: as_of + 1)
      create(:employee, hire_date: Date.new(2024, 1, 1), exit_date: as_of - 1)
    end

    it "names each group, echoes as_of and defaults to department" do
      body = run_rate

      expect(body).to include("as_of" => "2024-06-01", "group_by" => "department")
      expect(body["data"]).to eq([ {
        "group" => { "id" => engineering.id, "name" => "Engineering" },
        "headcount" => 2, "salaried" => 1, "gross_cents" => 10_000_000, "loaded_cents" => 12_000_000
      } ])
    end

    it "names country and level groups" do
      employee = Employee.active_as_of(as_of).first

      expect(run_rate(group_by: "country")["data"].pluck("group")).to include("id" => employee.country_id, "name" => employee.country.name)
      expect(run_rate(group_by: "level")["data"].pluck("group")).to include("id" => employee.level_id, "name" => employee.level.name)
    end

    it "counts the same active employees as the employee list" do
      totals = run_rate["totals"]

      get "/api/v1/employees", params: { as_of: as_of.iso8601, status: "active" }, headers: bearer_headers(user)

      expect(totals["headcount"]).to eq(response.parsed_body["pagination"]["total"])
    end

    [ { group_by: "title" }, { group_by: [ "level" ] }, { as_of: "June" } ].each do |params|
      it "refuses #{params.to_json}" do
        body = run_rate(**params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(body["error"]["details"].pluck("field")).to eq([ params.keys.first.to_s ])
      end
    end
  end
end
