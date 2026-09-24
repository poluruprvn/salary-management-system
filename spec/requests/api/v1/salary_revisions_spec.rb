require 'swagger_helper'

RSpec.describe "Salary revisions" do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{AccessToken.encode(user)}" }
  let(:employee) { create(:employee, hire_date: Date.new(2024, 1, 1)) }
  let(:employee_id) { employee.id }

  uuid = { type: :string, format: :uuid }
  attributes_schema = {
    amount_cents: { type: :integer, format: :int64, minimum: 1, description: "The new annual salary, in minor units" },
    effective_date: { type: :string, format: :date, description: "May be in the future. Must fall inside the employment." },
    reason: { type: :string, enum: SalaryRevision::REASONS },
    note: { type: :string, nullable: true }
  }

  def revise(effective_date, amount_cents, *traits)
    create(:salary_revision, *traits, employee: employee, effective_date: effective_date, amount_cents: amount_cents)
  end

  path "/api/v1/employees/{employee_id}/salary_revisions" do
    parameter name: :employee_id, in: :path, schema: uuid

    get "List an employee's salary history" do
      tags "Salary revisions"
      produces "application/json"
      description "Live revisions, newest first, each with the amount in force before it. Voided ones are left out."

      response "200", "the history" do
        schema type: :object, required: %w[data], properties: {
          data: { type: :array, items: { "$ref" => "#/components/schemas/salary_history_entry" } }
        }
        before do
          revise(Date.new(2024, 1, 1), 12_000_000)
          revise(Date.new(2025, 1, 1), 13_200_000)
        end
        run_test!
      end

      response "404", "no employee has that id" do
        schema "$ref" => "#/components/schemas/error"
        let(:employee_id) { SecureRandom.uuid }
        run_test!
      end

      requires_a_token
    end

    post "Add a salary revision" do
      tags "Salary revisions"
      consumes "application/json"
      produces "application/json"
      description <<~TEXT.squish
        A raise is a new revision, never an edit. The response carries the revision in force before it, so a form
        can show the change without a second request. A backdated revision also changes the previous amount of the
        one after it, so reload the history rather than patching a row.
      TEXT
      parameter name: :body, in: :body, required: true, schema: {
        type: :object, required: %w[amount_cents effective_date reason], properties: attributes_schema
      }

      let(:body) { { amount_cents: 13_200_000, effective_date: "2025-01-01", reason: "merit" } }

      response "201", "created, with the revision it follows" do
        schema "$ref" => "#/components/schemas/salary_change"
        before { revise(Date.new(2024, 1, 1), 12_000_000) }
        run_test!
      end

      response "404", "no employee has that id" do
        schema "$ref" => "#/components/schemas/error"
        let(:employee_id) { SecureRandom.uuid }
        run_test!
      end

      response "422", "an attribute is invalid, or a live revision already has that date" do
        schema "$ref" => "#/components/schemas/error"
        let(:body) { super().merge(reason: "bonus") }
        run_test!
      end

      requires_a_token
    end
  end

  path "/api/v1/employees/{employee_id}/salary_revisions/{id}" do
    parameter name: :employee_id, in: :path, schema: uuid
    parameter name: :id, in: :path, schema: uuid

    let(:revision) { revise(Date.new(2024, 1, 1), 12_000_000) }
    let(:id) { revision.id }

    patch "Correct a salary revision" do
      tags "Salary revisions"
      consumes "application/json"
      produces "application/json"
      description "For fixing a mistake. A raise is a new revision. A voided revision cannot be edited."
      parameter name: :body, in: :body, required: true, schema: { type: :object, properties: attributes_schema }

      let(:body) { { amount_cents: 12_500_000, note: "typo in the offer letter" } }

      response "200", "corrected" do
        schema "$ref" => "#/components/schemas/salary_revision"
        run_test!
      end

      response "404", "no revision with that id belongs to this employee" do
        schema "$ref" => "#/components/schemas/error"
        let(:id) { SecureRandom.uuid }
        run_test!
      end

      response "422", "an attribute is invalid" do
        schema "$ref" => "#/components/schemas/error"
        let(:body) { { amount_cents: 0 } }
        run_test!
      end

      requires_a_token
    end

    delete "Void a salary revision" do
      tags "Salary revisions"
      produces "application/json"
      description "The row is kept with voided_at set, and drops out of every read. Voiding twice is a no-op."

      response "204", "voided" do
        run_test!
      end

      response "404", "no revision with that id belongs to this employee" do
        schema "$ref" => "#/components/schemas/error"
        let(:id) { SecureRandom.uuid }
        run_test!
      end

      requires_a_token
    end
  end

  describe "GET /api/v1/employees/:employee_id/salary_revisions" do
    it "lists the live history newest first, each with the amount before it" do
      revise(Date.new(2024, 1, 1), 12_000_000)
      revise(Date.new(2024, 6, 1), 99_000_000, :voided)
      latest = revise(Date.new(2025, 1, 1), 13_200_000)

      get "/api/v1/employees/#{employee.id}/salary_revisions", headers: bearer_headers(user)

      expect(response.parsed_body["data"].map { |row| row.slice("effective_date", "amount_cents", "previous_amount_cents") }).to eq([
        { "effective_date" => "2025-01-01", "amount_cents" => 13_200_000, "previous_amount_cents" => 12_000_000 },
        { "effective_date" => "2024-01-01", "amount_cents" => 12_000_000, "previous_amount_cents" => nil }
      ])
      expect(response.parsed_body["data"].first["id"]).to eq(latest.id)
    end
  end

  describe "POST /api/v1/employees/:employee_id/salary_revisions" do
    def add(attributes)
      post "/api/v1/employees/#{employee.id}/salary_revisions", params: attributes, headers: bearer_headers(user), as: :json
      response.parsed_body
    end

    it "returns the revision it follows, so the form can show the raise" do
      revise(Date.new(2024, 1, 1), 12_000_000)

      body = add(amount_cents: 13_200_000, effective_date: "2025-01-01", reason: "merit")

      expect(response).to have_http_status(:created)
      expect(body).to include(
        "amount_cents" => 13_200_000, "effective_date" => "2025-01-01", "reason" => "merit",
        "previous_amount_cents" => 12_000_000, "previous_effective_date" => "2024-01-01"
      )
    end

    it "returns null previous values for the first revision" do
      body = add(amount_cents: 12_000_000, effective_date: "2024-01-01", reason: "merit")

      expect(body).to include("previous_amount_cents" => nil, "previous_effective_date" => nil)
    end

    it "is 422 on a date a live revision already holds" do
      revise(Date.new(2024, 1, 1), 12_000_000)

      body = add(amount_cents: 13_200_000, effective_date: "2024-01-01", reason: "merit")

      expect(response).to have_http_status(:unprocessable_content)
      expect(body.dig("error", "details")).to eq([ { "field" => "effective_date", "message" => "has already been taken" } ])
    end

    it "is 422 on a date before the hire date" do
      body = add(amount_cents: 12_000_000, effective_date: "2023-12-31", reason: "merit")

      expect(response).to have_http_status(:unprocessable_content)
      expect(body.dig("error", "details", 0, "message")).to eq("must be on or after the hire date")
    end
  end

  describe "PATCH /api/v1/employees/:employee_id/salary_revisions/:id" do
    it "is 422 on a voided revision" do
      revision = revise(Date.new(2024, 1, 1), 12_000_000, :voided)

      patch "/api/v1/employees/#{employee.id}/salary_revisions/#{revision.id}",
            params: { amount_cents: 12_500_000 }, headers: bearer_headers(user), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "message")).to eq("A voided revision cannot be edited")
    end
  end

  describe "DELETE /api/v1/employees/:employee_id/salary_revisions/:id" do
    it "voids the revision and keeps the row, and a second call changes nothing" do
      revision = revise(Date.new(2024, 1, 1), 12_000_000)

      delete "/api/v1/employees/#{employee.id}/salary_revisions/#{revision.id}", headers: bearer_headers(user)
      voided_at = revision.reload.voided_at

      expect(response).to have_http_status(:no_content)
      expect(voided_at).to be_present

      delete "/api/v1/employees/#{employee.id}/salary_revisions/#{revision.id}", headers: bearer_headers(user)

      expect(response).to have_http_status(:no_content)
      expect(revision.reload.voided_at).to eq(voided_at)
    end

    it "is 404 for another employee's revision" do
      other = create(:salary_revision, employee: create(:employee, hire_date: Date.new(2024, 1, 1)))

      delete "/api/v1/employees/#{employee.id}/salary_revisions/#{other.id}", headers: bearer_headers(user)

      expect(response).to have_http_status(:not_found)
      expect(other.reload.voided_at).to be_nil
    end
  end
end
