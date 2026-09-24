require 'swagger_helper'

RSpec.describe "Reference data" do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{AccessToken.encode(user)}" }

  def list(resource)
    get "/api/v1/#{resource}", headers: bearer_headers(user)
    response.parsed_body["data"]
  end

  { countries: :country, departments: :department, levels: :level }.each do |resource, schema_name|
    path "/api/v1/#{resource}" do
      get "List #{resource}" do
        tags "Reference data"
        produces "application/json"
        description "A closed set, returned whole and unpaginated."

        response "200", "every #{schema_name}" do
          schema type: :object, required: %w[data], properties: {
            data: { type: :array, items: { "$ref" => "#/components/schemas/#{schema_name}" } }
          }
          before { create(schema_name) }
          run_test!
        end

        requires_a_token
      end
    end
  end

  it "lists departments by name, ignoring case" do
    %w[Sales engineering Finance].each { |name| create(:department, name: name) }

    expect(list(:departments).pluck("name")).to eq(%w[engineering Finance Sales])
  end

  it "lists countries by name, ignoring case" do
    create(:country, code: "IN", name: "India")
    create(:country, code: "FR", name: "France")
    create(:country, code: "AE", name: "aland")

    expect(list(:countries).pluck("code")).to eq(%w[AE FR IN])
  end

  it "lists levels by rank, so L2 comes before L10" do
    create(:level, code: "L10", rank: 10)
    create(:level, code: "L2", rank: 2)

    expect(list(:levels).pluck("code")).to eq(%w[L2 L10])
  end
end
