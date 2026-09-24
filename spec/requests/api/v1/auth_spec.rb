require 'swagger_helper'

RSpec.describe "Auth" do
  let(:password) { "correct horse battery staple" }
  let!(:user) { create(:user, email: "hr@example.com", password: password) }

  path "/api/v1/auth/sign_in" do
    post "Exchange credentials for a token pair" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      security []
      parameter name: :credentials, in: :body, required: true, schema: {
        type: :object,
        required: %w[email password],
        properties: { email: { type: :string, format: :email }, password: { type: :string } }
      }

      response "200", "signed in" do
        schema "$ref" => "#/components/schemas/token_pair"
        let(:credentials) { { email: user.email, password: password } }
        run_test!
      end

      response "400", "a credential is missing" do
        schema "$ref" => "#/components/schemas/error"
        let(:credentials) { { email: user.email } }
        run_test!
      end

      response "401", "the email or the password is wrong" do
        schema "$ref" => "#/components/schemas/error"
        let(:credentials) { { email: user.email, password: "wrong" } }
        run_test!
      end
    end
  end

  path "/api/v1/auth/refresh" do
    post "Rotate a refresh token for a new pair" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      security []
      parameter name: :token, in: :body, required: true, schema: {
        type: :object,
        required: %w[refresh_token],
        properties: { refresh_token: { type: :string } }
      }

      response "200", "rotated, and the old refresh token is now dead" do
        schema "$ref" => "#/components/schemas/token_pair"
        let(:token) { { refresh_token: Auth::SignIn.call(email: user.email, password: password).refresh_token } }
        run_test!
      end

      response "400", "no refresh token" do
        schema "$ref" => "#/components/schemas/error"
        let(:token) { {} }
        run_test!
      end

      response "401", "the refresh token is expired or has already been used" do
        schema "$ref" => "#/components/schemas/error"
        let(:token) { { refresh_token: "nope" } }
        run_test!
      end
    end
  end

  path "/api/v1/auth/sign_out" do
    delete "Delete every refresh token for the signed in user" do
      tags "Auth"
      produces "application/json"

      response "204", "signed out" do
        let(:Authorization) { "Bearer #{AccessToken.encode(user)}" }
        run_test!
      end

      response "401", "the access token is missing or invalid" do
        schema "$ref" => "#/components/schemas/error"
        let(:Authorization) { "Bearer nope" }
        run_test!
      end
    end
  end
end
