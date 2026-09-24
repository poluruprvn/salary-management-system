require 'rails_helper'

RSpec.describe "Api::V1::Sessions" do
  let(:password) { "correct horse battery staple" }
  let!(:user) { create(:user, email: "hr@example.com", password: password) }

  def sign_in(email: "hr@example.com", password: "correct horse battery staple")
    post "/api/v1/auth/sign_in", params: { email: email, password: password }, as: :json
    response.parsed_body
  end

  def bearer(token) = { "Authorization" => "Bearer #{token}" }

  describe "POST /api/v1/auth/sign_in" do
    it "returns a pair and records the refresh token" do
      body = sign_in

      expect(response).to have_http_status(:ok)
      expect(body["expires_in"]).to eq(AccessToken::LIFETIME.to_i)
      expect(AccessToken.decode(body["access_token"])["sub"]).to eq(user.id)
      expect(user.refresh_tokens.sole.token_digest).to eq(RefreshToken.digest(body["refresh_token"]))
    end

    it "refuses a wrong password in the documented shape" do
      body = sign_in(password: "wrong")

      expect(response).to have_http_status(:unauthorized)
      expect(body["error"]).to eq(
        "code" => "invalid_credentials", "message" => "Email or password is incorrect", "details" => []
      )
      expect(RefreshToken.count).to eq(0)
    end

    it "refuses an unknown email" do
      sign_in(email: "nobody@example.com")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_credentials")
    end

    it "is 400 when a credential is missing" do
      post "/api/v1/auth/sign_in", params: { email: "hr@example.com" }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq(
        "code" => "parameter_missing",
        "message" => "password is required",
        "details" => [ { "field" => "password", "message" => "is required" } ]
      )
    end
  end

  describe "a body that is not JSON" do
    it "is 400 in the documented shape" do
      post "/api/v1/auth/sign_in", params: "{bad json", headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq(
        "code" => "malformed_body", "message" => "Request body could not be parsed", "details" => []
      )
    end
  end

  describe "POST /api/v1/auth/refresh" do
    it "rotates the row and returns a new pair" do
      issued = sign_in

      post "/api/v1/auth/refresh", params: { refresh_token: issued["refresh_token"] }, as: :json
      body = response.parsed_body

      expect(response).to have_http_status(:ok)
      expect(body["refresh_token"]).not_to eq(issued["refresh_token"])
      expect(user.refresh_tokens.sole.token_digest).to eq(RefreshToken.digest(body["refresh_token"]))
    end

    it "refuses a replayed token" do
      issued = sign_in
      post "/api/v1/auth/refresh", params: { refresh_token: issued["refresh_token"] }, as: :json

      post "/api/v1/auth/refresh", params: { refresh_token: issued["refresh_token"] }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_refresh_token")
    end

    it "is 400 without a token" do
      post "/api/v1/auth/refresh", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /api/v1/auth/sign_out" do
    it "deletes every refresh row for the user and leaves other users alone" do
      issued = sign_in
      other = create(:refresh_token)
      create(:refresh_token, user: user)

      delete "/api/v1/auth/sign_out", headers: bearer(issued["access_token"])

      expect(response).to have_http_status(:no_content)
      expect(user.refresh_tokens.reload).to be_empty
      expect(RefreshToken.exists?(other.id)).to be(true)
    end

    it "makes the refresh token unusable" do
      issued = sign_in
      delete "/api/v1/auth/sign_out", headers: bearer(issued["access_token"])

      post "/api/v1/auth/refresh", params: { refresh_token: issued["refresh_token"] }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    # The accepted cost of having no denylist: sign out ends a session within one access token lifetime.
    it "leaves an access token minted before sign out working until it expires" do
      issued = sign_in
      delete "/api/v1/auth/sign_out", headers: bearer(issued["access_token"])

      delete "/api/v1/auth/sign_out", headers: bearer(issued["access_token"])

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "authenticating a request" do
    it "is 401 with no header" do
      delete "/api/v1/auth/sign_out"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to eq(
        "code" => "invalid_token", "message" => "Access token is missing or invalid", "details" => []
      )
    end

    it "is 401 on a header that is not a bearer token" do
      [ "Token abc", "Bearer", "Bearer ", "abc" ].each do |header|
        delete "/api/v1/auth/sign_out", headers: { "Authorization" => header }

        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
      end
    end

    it "is 401 token_expired once the lifetime has passed" do
      issued = sign_in

      travel_to(AccessToken::LIFETIME.from_now + 1.second) do
        delete "/api/v1/auth/sign_out", headers: bearer(issued["access_token"])
      end

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("token_expired")
    end

    it "is 401 invalid_token on a tampered payload" do
      header, _payload, signature = sign_in["access_token"].split(".")
      forged = Base64.urlsafe_encode64({ sub: SecureRandom.uuid }.to_json, padding: false)

      delete "/api/v1/auth/sign_out", headers: bearer([ header, forged, signature ].join("."))

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
    end

    it "is 401 when the token names a user who no longer exists" do
      token = AccessToken.encode(user)
      user.destroy!

      delete "/api/v1/auth/sign_out", headers: bearer(token)

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
    end
  end
end
