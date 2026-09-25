require 'swagger_helper'

RSpec.describe "Countries" do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{AccessToken.encode(user)}" }
  let(:country) { create(:country, code: "FR", employer_cost_multiplier: "1.2") }

  path "/api/v1/countries/{id}" do
    parameter name: :id, in: :path, schema: { type: :string, format: :uuid }

    let(:id) { country.id }

    patch "Update a country's employer cost multiplier" do
      tags "Reference data"
      consumes "application/json"
      produces "application/json"
      description "Only the multiplier is editable. Every fully loaded figure uses the current value, past dates included."
      parameter name: :body, in: :body, required: true, schema: {
        type: :object, properties: {
          employer_cost_multiplier: { type: :string, example: "1.45", description: "Above 0, below 100, at most 4 decimal places" }
        }
      }

      let(:body) { { employer_cost_multiplier: "1.45" } }

      response "200", "updated" do
        schema "$ref" => "#/components/schemas/country"
        run_test!
      end

      response "404", "no country has that id" do
        schema "$ref" => "#/components/schemas/error"
        let(:id) { SecureRandom.uuid }
        run_test!
      end

      response "422", "the multiplier is invalid" do
        schema "$ref" => "#/components/schemas/error"
        let(:body) { { employer_cost_multiplier: "0" } }
        run_test!
      end

      requires_a_token
    end
  end

  describe "PATCH /api/v1/countries/:id" do
    def update(body)
      patch "/api/v1/countries/#{country.id}", params: body, headers: bearer_headers(user), as: :json
      response.parsed_body
    end

    it "saves the multiplier and returns it as a string" do
      body = update(employer_cost_multiplier: "1.4567")

      expect(response).to have_http_status(:ok)
      expect(body["employer_cost_multiplier"]).to eq("1.4567")
      expect(country.reload.employer_cost_multiplier).to eq(BigDecimal("1.4567"))
    end

    [ "0", "100", "1.45678" ].each do |value|
      it "refuses #{value}" do
        body = update(employer_cost_multiplier: value)

        expect(response).to have_http_status(:unprocessable_content)
        expect(body["error"]["details"].pluck("field")).to eq([ "employer_cost_multiplier" ])
        expect(country.reload.employer_cost_multiplier).to eq(BigDecimal("1.2"))
      end
    end

    [ {}, { employer_cost_multiplier: [ "1.3" ] }, { employer_cost_multiplier: nil }, { employer_cost_multiplier: "" } ].each do |body|
      it "refuses #{body.to_json} as a missing parameter" do
        update(body)

        expect(response).to have_http_status(:bad_request)
        expect(country.reload.employer_cost_multiplier).to eq(BigDecimal("1.2"))
      end
    end

    it "ignores code and name" do
      update(employer_cost_multiplier: "1.3", code: "DE", name: "Germany")

      expect(country.reload).to have_attributes(code: "FR", employer_cost_multiplier: BigDecimal("1.3"))
      expect(country.name).not_to eq("Germany")
    end

    it "records the signed in user in the audit trail" do
      update(employer_cost_multiplier: "1.3")

      audit = country.audits.last
      expect(audit.user).to eq(user)
      expect(audit.audited_changes).to eq("employer_cost_multiplier" => [ "1.2", "1.3" ])
    end
  end
end
