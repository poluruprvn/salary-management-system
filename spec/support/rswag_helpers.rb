module RswagHelpers
  # Every operation behind the bearer token documents the same 401.
  def requires_a_token
    response "401", "the access token is missing or invalid" do
      schema "$ref" => "#/components/schemas/error"
      let(:Authorization) { "Bearer nope" }
      run_test!
    end
  end
end

RSpec.configure do |config|
  config.extend RswagHelpers, type: :request
end
