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

  path "/api/v1/analytics/distribution" do
    get "Salary percentiles by group" do
      tags "Analytics"
      produces "application/json"
      description "Salaried active employees on as_of, filtered, then grouped. q and status are refused: status is always active here."
      parameter name: :group_by, in: :query, required: false,
                schema: { type: :string, enum: Employee::DISTRIBUTION_KEYS.keys, default: "department" }
      parameter name: "department_id[]", in: :query, required: false, getter: :department_ids,
                schema: { type: :array, items: { type: :string, format: :uuid } }
      parameter name: "country_id[]", in: :query, required: false, getter: :country_ids,
                schema: { type: :array, items: { type: :string, format: :uuid } }
      parameter name: "level_id[]", in: :query, required: false, getter: :level_ids,
                schema: { type: :array, items: { type: :string, format: :uuid } }
      parameter name: :title, in: :query, required: false, schema: { type: :string }, description: "The whole title"
      parameter name: :sort, in: :query, required: false,
                schema: { type: :string, enum: %w[name headcount median].flat_map { |key| [ key, "-#{key}" ] } },
                description: "A leading - sorts descending. Defaults to name, or -headcount for title. name is rank for level."
      parameter as_of_parameter
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1, default: 1 }
      parameter name: :per_page, in: :query, required: false, schema: { type: :integer, minimum: 1, default: 25 },
                description: "Above 100 is clamped to 100, not refused"

      response "200", "a page of groups" do
        schema type: :object, required: %w[as_of group_by data unsalaried pagination], properties: {
          as_of: { type: :string, format: :date },
          group_by: { type: :string, enum: Employee::DISTRIBUTION_KEYS.keys },
          data: {
            type: :array,
            items: {
              type: :object,
              required: %w[group headcount min_cents p25_cents median_cents p75_cents max_cents],
              properties: {
                group: {
                  type: :object, required: %w[id name],
                  properties: {
                    id: { type: :string, description: "A uuid, or the title itself for title" },
                    name: { type: :string }
                  }
                },
                headcount: { type: :integer, description: "Salaried employees in the group" },
                min_cents: cents,
                p25_cents: cents.merge(description: "Interpolated, rounded half up to the cent"),
                median_cents: cents.merge(description: "Interpolated, rounded half up to the cent"),
                p75_cents: cents.merge(description: "Interpolated, rounded half up to the cent"),
                max_cents: cents
              }
            }
          },
          unsalaried: { type: :integer, description: "Active employees the filters matched who have no salary on file" },
          pagination: { "$ref" => "#/components/schemas/pagination" }
        }

        before { create(:salary_revision) }

        run_test!
      end

      response "422", "a filter, group_by, sort, as_of, page or per_page is invalid" do
        schema "$ref" => "#/components/schemas/error"
        let(:sort) { "salary" }
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

  describe "GET /api/v1/analytics/distribution" do
    let(:as_of) { Date.new(2024, 6, 1) }
    let(:engineering) { create(:department, name: "Engineering") }
    let(:level) { create(:level, name: "Senior") }

    def distribution(**params)
      get "/api/v1/analytics/distribution", params: { as_of: as_of.iso8601, **params }, headers: bearer_headers(user)
      response.parsed_body
    end

    before do
      [ 1_000_000, 3_000_000 ].each do |salary|
        employee = create(:employee, department: engineering, level: level, title: "Engineer", hire_date: Date.new(2024, 1, 1))
        create(:salary_revision, employee: employee, amount_cents: salary)
      end
      create(:employee, department: engineering, level: level, hire_date: Date.new(2024, 1, 1))
    end

    it "names each group, counts the unsalaried, and pages" do
      body = distribution

      expect(body).to include("as_of" => "2024-06-01", "group_by" => "department", "unsalaried" => 1)
      expect(body["data"]).to eq([ {
        "group" => { "id" => engineering.id, "name" => "Engineering" }, "headcount" => 2,
        "min_cents" => 1_000_000, "p25_cents" => 1_500_000, "median_cents" => 2_000_000, "p75_cents" => 2_500_000, "max_cents" => 3_000_000
      } ])
      expect(body["pagination"]).to include("total" => 1, "page" => 1)
    end

    it "uses the title as its own id and pages titles" do
      other = create(:employee, title: "Analyst", hire_date: Date.new(2024, 1, 1))
      create(:salary_revision, employee: other)

      body = distribution(group_by: "title", per_page: 1)

      expect(body["data"].pluck("group")).to eq([ { "id" => "Engineer", "name" => "Engineer" } ])
      expect(body["pagination"]).to include("total" => 2, "total_pages" => 2, "next_page" => 2)
      expect(distribution(group_by: "title", per_page: 1, page: 2)["data"].pluck("group")).to eq([ { "id" => "Analyst", "name" => "Analyst" } ])
      expect(distribution(group_by: "title", sort: "name", per_page: 1)["data"].pluck("group")).to eq([ { "id" => "Analyst", "name" => "Analyst" } ])
    end

    it "filters before grouping" do
      body = distribution(group_by: "level", level_id: [ level.id ], department_id: engineering.id, title: "Engineer")

      expect(body["data"].pluck("group", "headcount")).to eq([ [ { "id" => level.id, "name" => "Senior" }, 2 ] ])
      expect(distribution(department_id: [ create(:department).id ])).to include("data" => [], "unsalaried" => 0)
      expect(distribution(country_id: [ create(:country).id ])).to include("data" => [], "unsalaried" => 0)
    end

    [ { group_by: "email" }, { sort: "salary" }, { q: "Ada" }, { status: "active" }, { title: [ "Engineer" ] }, { country_id: { "x" => "1" } }, { as_of: "June" } ].each do |params|
      it "refuses #{params.to_json}" do
        body = distribution(**params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(body["error"]["details"].pluck("field")).to eq([ params.keys.first.to_s ])
      end
    end
  end
end
