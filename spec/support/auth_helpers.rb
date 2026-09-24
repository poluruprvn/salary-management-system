module AuthHelpers
  def bearer_headers(user)
    { "Authorization" => "Bearer #{AccessToken.encode(user)}" }
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
