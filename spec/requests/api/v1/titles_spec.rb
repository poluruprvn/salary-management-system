require 'swagger_helper'

RSpec.describe "Titles" do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{AccessToken.encode(user)}" }

  path "/api/v1/titles" do
    get "Suggest titles already in use" do
      tags "Titles"
      produces "application/json"
      description <<~TEXT.squish
        For the title typeahead. Distinct titles with how many employees ever held them, most used first, capped at
        #{Api::V1::TitlesController::LIMIT}. It truncates rather than paginates.
      TEXT
      parameter name: :q, in: :query, required: false, schema: { type: :string },
                description: "Matches anywhere in the title, ignoring case"

      response "200", "the most used matching titles" do
        schema type: :object, required: %w[data], properties: {
          data: { type: :array, items: { "$ref" => "#/components/schemas/title_count" } }
        }
        let(:q) { "eng" }
        before { create(:employee, title: "Senior Engineer") }
        run_test!
      end

      requires_a_token
    end
  end

  describe "GET /api/v1/titles" do
    def suggest(q = nil)
      get "/api/v1/titles", params: { q: q }.compact, headers: bearer_headers(user)
      response.parsed_body["data"]
    end

    it "counts every employee ever, most used first" do
      create_list(:employee, 2, title: "Senior Engineer")
      create(:employee, title: "Sr. Engineer", exit_date: Date.yesterday)
      create(:employee, title: "Accountant")

      expect(suggest("ENGINEER")).to eq([
        { "title" => "Senior Engineer", "employee_count" => 2 },
        { "title" => "Sr. Engineer", "employee_count" => 1 }
      ])
    end

    it "stops at the cap" do
      (Api::V1::TitlesController::LIMIT + 1).times { |n| create(:employee, title: "Engineer #{n}") }

      expect(suggest.size).to eq(Api::V1::TitlesController::LIMIT)
    end
  end
end
