require 'swagger_helper'

RSpec.describe "Employees" do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{AccessToken.encode(user)}" }

  uuid = { type: :string, format: :uuid }
  attributes_schema = {
    name: { type: :string, maxLength: 255 },
    email: { type: :string, format: :email, maxLength: 255 },
    title: { type: :string, maxLength: 255, description: "Free text. GET /api/v1/titles offers the ones already in use." },
    hire_date: { type: :string, format: :date },
    exit_date: { type: :string, format: :date, nullable: true },
    country_id: uuid,
    department_id: uuid,
    level_id: uuid
  }
  as_of_parameter = {
    name: :as_of, in: :query, required: false, schema: { type: :string, format: :date },
    description: "Defaults to today. Status and current_salary are computed for this date, and it is echoed back."
  }

  path "/api/v1/employees" do
    get "List employees" do
      tags "Employees"
      produces "application/json"
      description "Search, filter, sort and pagination all run on the server."
      parameter name: :q, in: :query, required: false, schema: { type: :string },
                description: "Part of the name, email or title, ignoring case. A whole UUID matches the id instead."
      parameter name: "department_id[]", in: :query, required: false, getter: :department_ids,
                schema: { type: :array, items: uuid }
      parameter name: "country_id[]", in: :query, required: false, getter: :country_ids,
                schema: { type: :array, items: uuid }
      parameter name: "level_id[]", in: :query, required: false, getter: :level_ids,
                schema: { type: :array, items: uuid }
      parameter name: :title, in: :query, required: false, schema: { type: :string }, description: "The whole title"
      parameter name: :status, in: :query, required: false, getter: :status_filter,
                schema: { type: :string, enum: Employee::STATUSES }, description: "As of as_of"
      parameter name: :sort, in: :query, required: false,
                schema: { type: :string, enum: Employee::SORT_KEYS.keys.flat_map { |key| [ key, "-#{key}" ] }, default: "name" },
                description: "A leading - sorts descending. salary and exit_date put nulls last either way."
      parameter as_of_parameter
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1, default: 1 }
      parameter name: :per_page, in: :query, required: false, schema: { type: :integer, minimum: 1, default: 25 },
                description: "Above 100 is clamped to 100, not refused"

      response "200", "a page of employees" do
        schema type: :object, required: %w[data pagination], properties: {
          data: { type: :array, items: { "$ref" => "#/components/schemas/employee" } },
          pagination: { "$ref" => "#/components/schemas/pagination" }
        }

        let(:engineering) { create(:department) }
        let(:department_ids) { [ engineering.id ] }
        let!(:paid) { create(:employee, name: "Ada Lovelace", department: engineering, hire_date: Date.new(2024, 1, 1)) }
        let!(:leaver) { create(:employee, name: "Grace Hopper", department: engineering, exit_date: Date.yesterday) }

        before do
          create(:salary_revision, employee: paid, effective_date: Date.new(2024, 1, 1))
          create(:employee)
        end

        run_test! do |response|
          expect(response.parsed_body["data"].pluck("id")).to eq([ paid.id, leaver.id ])
        end
      end

      response "422", "a filter, sort, as_of, page or per_page is invalid" do
        schema "$ref" => "#/components/schemas/error"
        let(:sort) { "shoe_size" }
        run_test!
      end

      requires_a_token
    end

    post "Create an employee" do
      tags "Employees"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, required: true, schema: {
        type: :object, required: %w[name email title hire_date country_id department_id level_id], properties: attributes_schema
      }

      let(:body) do
        { name: "Ada Lovelace", email: "ada@example.com", title: "Engineer", hire_date: "2024-01-01",
          country_id: create(:country).id, department_id: create(:department).id, level_id: create(:level).id }
      end

      response "201", "created" do
        schema "$ref" => "#/components/schemas/employee"
        run_test!
      end

      response "422", "an attribute is invalid, or the email is already in use" do
        schema "$ref" => "#/components/schemas/error"
        let(:body) { super().merge(email: "not an email") }
        run_test!
      end

      requires_a_token
    end
  end

  path "/api/v1/employees/{id}" do
    parameter name: :id, in: :path, schema: uuid

    let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }
    let(:id) { employee.id }

    get "Show an employee" do
      tags "Employees"
      produces "application/json"
      parameter as_of_parameter

      response "200", "the employee" do
        schema "$ref" => "#/components/schemas/employee"
        before { create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1)) }
        run_test!
      end

      response "404", "no employee has that id" do
        schema "$ref" => "#/components/schemas/error"
        let(:id) { SecureRandom.uuid }
        run_test!
      end

      response "422", "as_of is not a date" do
        schema "$ref" => "#/components/schemas/error"
        let(:as_of) { "yesterday" }
        run_test!
      end

      requires_a_token
    end

    patch "Update an employee" do
      tags "Employees"
      consumes "application/json"
      produces "application/json"
      description "Send only the attributes that change. A null exit_date clears it."
      parameter name: :body, in: :body, required: true, schema: { type: :object, properties: attributes_schema }

      let(:body) { { title: "Staff Engineer" } }

      response "200", "updated" do
        schema "$ref" => "#/components/schemas/employee"
        run_test!
      end

      response "404", "no employee has that id" do
        schema "$ref" => "#/components/schemas/error"
        let(:id) { SecureRandom.uuid }
        run_test!
      end

      response "422", "an attribute is invalid" do
        schema "$ref" => "#/components/schemas/error"
        let(:body) { { exit_date: "2023-12-31" } }
        run_test!
      end

      requires_a_token
    end
  end

  describe "GET /api/v1/employees" do
    def list(params = {})
      get "/api/v1/employees", params: params, headers: bearer_headers(user)
      response.parsed_body
    end

    it "reports the pagination envelope on the first, middle and last page" do
      %w[Ada Bea Cy Di Ed].each { |name| create(:employee, name: name) }

      first = list(per_page: 2, page: 1)
      expect(first["data"].pluck("name")).to eq(%w[Ada Bea])
      expect(first["pagination"]).to eq(
        "total" => 5, "page" => 1, "per_page" => 2, "total_pages" => 3, "prev_page" => nil, "next_page" => 2
      )

      middle = list(per_page: 2, page: 2)
      expect(middle["data"].pluck("name")).to eq(%w[Cy Di])
      expect(middle["pagination"]).to include("page" => 2, "prev_page" => 1, "next_page" => 3)

      last = list(per_page: 2, page: 3)
      expect(last["data"].pluck("name")).to eq(%w[Ed])
      expect(last["pagination"]).to include("page" => 3, "prev_page" => 2, "next_page" => nil)
    end

    it "counts only what the filters keep" do
      engineering = create(:department)
      create_list(:employee, 2, department: engineering)
      create(:employee)

      body = list("department_id" => [ engineering.id ], per_page: 1)

      expect(body["pagination"]).to include("total" => 2, "total_pages" => 2)
      expect(response.headers["X-Total-Count"]).to eq("2")
    end

    it "defaults as_of to today and echoes it on every row" do
      travel_to Date.new(2026, 3, 15) do
        create_list(:employee, 2)

        expect(list["data"].pluck("as_of")).to eq(%w[2026-03-15 2026-03-15])
      end
    end

    it "reads status and the salary in force as of the date asked for" do
      employee = create(:employee, hire_date: Date.new(2024, 1, 1))
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1), amount_cents: 12_000_000)
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 9, 1), amount_cents: 13_200_000)

      expect(list(as_of: "2023-12-31")["data"].sole).to include("status" => "pending", "current_salary" => nil)
      expect(list(as_of: "2024-08-31")["data"].sole).to include(
        "status" => "active", "as_of" => "2024-08-31",
        "current_salary" => { "amount_cents" => 12_000_000, "effective_date" => "2024-01-01" }
      )
      expect(list(as_of: "2024-09-01")["data"].sole.dig("current_salary", "amount_cents")).to eq(13_200_000)
    end

    it "sorts the highest paid first on -salary, and the unpaid last" do
      unpaid = create(:employee, hire_date: Date.new(2024, 1, 1))
      low, high = [ 10_000_000, 20_000_000 ].map do |amount_cents|
        create(:employee, hire_date: Date.new(2024, 1, 1)).tap do |employee|
          create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1), amount_cents: amount_cents)
        end
      end

      expect(list(sort: "-salary", as_of: "2024-06-01")["data"].pluck("id")).to eq([ high.id, low.id, unpaid.id ])
    end

    it "carries the reference objects on every row" do
      employee = create(:employee)

      expect(list["data"].sole).to include(
        "country" => { "id" => employee.country.id, "code" => employee.country.code, "name" => employee.country.name,
                       "employer_cost_multiplier" => "1.2" },
        "department" => { "id" => employee.department.id, "name" => employee.department.name },
        "level" => { "id" => employee.level.id, "code" => employee.level.code, "name" => employee.level.name,
                     "rank" => employee.level.rank }
      )
    end

    it "is 422 naming as_of when it is not a YYYY-MM-DD date, never a fall back to today" do
      [ "2024-02-30", "yesterday", "2024-6-1", "20240601", "2024-06-01T00:00:00Z" ].each do |as_of|
        body = list(as_of: as_of)

        expect(response).to have_http_status(:unprocessable_content)
        expect(body.dig("error", "details")).to eq([ { "field" => "as_of", "message" => "must be a date as YYYY-MM-DD" } ])
      end
    end

    it "is 422 on a status the list cannot return" do
      body = list(status: "retired")

      expect(response).to have_http_status(:unprocessable_content)
      expect(body.dig("error", "details", 0, "field")).to eq("status")
    end

    it "is an empty page, not an error, for a filter id that is not a UUID" do
      create(:employee)

      expect(list("department_id" => [ "nonsense" ])["data"]).to be_empty
      expect(response).to have_http_status(:ok)
    end

    it "is 422 on a list where a filter takes one value, rather than dropping the filter" do
      create(:employee, exit_date: Date.yesterday)

      body = list("status" => [ "active" ])

      expect(response).to have_http_status(:unprocessable_content)
      expect(body.dig("error", "details")).to eq([ { "field" => "status", "message" => "must be a single value" } ])
    end

    it "is 422 on an id filter sent as a hash, rather than dropping the filter" do
      create(:employee)

      [ { department_id: { "x" => "1" } }, { level_id: [ { "a" => "b" } ] } ].each do |params|
        body = list(params)

        expect(response).to have_http_status(:unprocessable_content)
        expect(body.dig("error", "details")).to eq([ { "field" => params.keys.first.to_s, "message" => "must be one id or a list of ids" } ])
      end
    end

    it "takes a single id for a filter as well as a list" do
      employee = create(:employee)
      create(:employee)

      expect(list(department_id: employee.department_id)["data"].pluck("id")).to eq([ employee.id ])
    end
  end

  describe "GET /api/v1/employees/:id" do
    it "reads the salary in force as of the date asked for, and nothing once exited" do
      employee = create(:employee, hire_date: Date.new(2024, 1, 1), exit_date: Date.new(2024, 6, 30))
      create(:salary_revision, employee: employee, effective_date: Date.new(2024, 1, 1), amount_cents: 12_000_000)

      get "/api/v1/employees/#{employee.id}", params: { as_of: "2024-06-30" }, headers: bearer_headers(user)
      expect(response.parsed_body).to include(
        "status" => "active", "as_of" => "2024-06-30",
        "current_salary" => { "amount_cents" => 12_000_000, "effective_date" => "2024-01-01" }
      )

      get "/api/v1/employees/#{employee.id}", params: { as_of: "2024-07-01" }, headers: bearer_headers(user)
      expect(response.parsed_body).to include("status" => "exited", "current_salary" => nil)
    end

    it "is 404 for an id that is not a UUID" do
      get "/api/v1/employees/nonsense", headers: bearer_headers(user)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig("error", "code")).to eq("not_found")
    end
  end

  describe "POST /api/v1/employees" do
    let(:attributes) do
      { name: " Ada  Lovelace ", email: "Ada@Example.com", title: "Engineer", hire_date: "2024-01-01",
        country_id: create(:country).id, department_id: create(:department).id, level_id: create(:level).id }
    end

    it "creates the employee and returns it normalized, with no salary yet" do
      post "/api/v1/employees", params: attributes, headers: bearer_headers(user), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "name" => "Ada Lovelace", "email" => "ada@example.com", "status" => "active", "current_salary" => nil
      )
      expect(Employee.find(response.parsed_body["id"]).name).to eq("Ada Lovelace")
    end

    it "ignores an id in the body, which only the database mints" do
      id = SecureRandom.uuid_v7

      post "/api/v1/employees", params: attributes.merge(id: id), headers: bearer_headers(user), as: :json

      expect(response.parsed_body["id"]).not_to eq(id)
    end

    it "is 422 naming the field on a duplicate email, in any case" do
      create(:employee, email: "ada@example.com")

      post "/api/v1/employees", params: attributes, headers: bearer_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to eq([ { "field" => "email", "message" => "has already been taken" } ])
    end

    # Two concurrent requests can both pass the validation. Only the index sees the second.
    it "is 422 with no details when the index catches a duplicate email the validation missed" do
      create(:employee, email: "ada@example.com")
      allow_any_instance_of(ActiveRecord::Validations::UniquenessValidator).to receive(:validate_each)

      post "/api/v1/employees", params: attributes, headers: bearer_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq(
        "code" => "validation_failed", "message" => "A record with these values already exists", "details" => []
      )
    end

    it "is 422 and writes nothing for a date sent as a number" do
      expect { post "/api/v1/employees", params: attributes.merge(hire_date: 20240101), headers: bearer_headers(user), as: :json }
        .not_to change(Employee, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to eq([ { "field" => "hire_date", "message" => "can't be blank" } ])
    end

    it "is 422 naming the reference that does not exist" do
      post "/api/v1/employees", params: attributes.merge(level_id: SecureRandom.uuid), headers: bearer_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to eq([ { "field" => "level", "message" => "must exist" } ])
    end
  end

  describe "PATCH /api/v1/employees/:id" do
    let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1), exit_date: Date.new(2025, 6, 30)) }

    def update(attributes)
      patch "/api/v1/employees/#{employee.id}", params: attributes, headers: bearer_headers(user), as: :json
    end

    it "changes only what was sent" do
      update(title: "Staff Engineer")

      expect(response).to have_http_status(:ok)
      expect(employee.reload).to have_attributes(title: "Staff Engineer", exit_date: Date.new(2025, 6, 30))
    end

    it "clears the exit date on null" do
      update(exit_date: nil)

      expect(employee.reload.exit_date).to be_nil
    end

    it "refuses a bad as_of before the write, so a 422 never follows a commit" do
      employee

      expect do
        patch "/api/v1/employees/#{employee.id}?as_of=06/01/2024", params: { title: "Staff Engineer" },
                                                                   headers: bearer_headers(user), as: :json
      end.not_to change(Audited::Audit, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(employee.reload.title).to eq("Engineer")
    end

    it "is 422 on an exit date that does not parse, rather than clearing it" do
      update(exit_date: "31/31/2025")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to eq([ { "field" => "exit_date", "message" => "is not a valid date" } ])
      expect(employee.reload.exit_date).to eq(Date.new(2025, 6, 30))
    end
  end
end
