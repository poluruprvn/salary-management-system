require 'swagger_helper'

RSpec.describe "Account" do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{AccessToken.encode(user)}" }

  path "/api/v1/me" do
    get "Show the signed in user" do
      tags "Account"
      produces "application/json"

      response "200", "the user the access token names" do
        schema "$ref" => "#/components/schemas/user"
        run_test! do |response|
          expect(response.parsed_body).to eq("id" => user.id, "name" => user.name, "email" => user.email)
        end
      end

      requires_a_token
    end
  end

  path "/api/v1/meta" do
    get "Show the currency, the enums and the server's today" do
      tags "Account"
      produces "application/json"

      response "200", "the settings a client needs before its first list" do
        schema "$ref" => "#/components/schemas/meta"
        run_test! do |response|
          expect(response.parsed_body).to eq(
            "base_currency" => "USD",
            "minor_unit" => 2,
            "today" => Date.current.iso8601,
            "employee_statuses" => Employee::STATUSES,
            "salary_revision_reasons" => SalaryRevision::REASONS
          )
        end
      end

      requires_a_token
    end
  end

  it "reads the base currency from BASE_CURRENCY" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("BASE_CURRENCY", "USD").and_return("EUR")

    get "/api/v1/meta", headers: bearer_headers(user)

    expect(response.parsed_body["base_currency"]).to eq("EUR")
  end
end
