require 'rails_helper'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/openapi.yaml" => {
      openapi: "3.0.1",
      info: { title: "Salary Management API", version: "v1" },
      servers: [ { url: "http://localhost:3000" } ],
      paths: {},
      components: {
        securitySchemes: {
          bearer_auth: { type: :http, scheme: :bearer, bearerFormat: "JWT" }
        },
        schemas: {
          token_pair: {
            type: :object,
            required: %w[access_token expires_in refresh_token],
            properties: {
              access_token: { type: :string },
              expires_in: { type: :integer, description: "Seconds the access token stays valid" },
              refresh_token: { type: :string }
            }
          },
          error: {
            type: :object,
            required: %w[error],
            properties: {
              error: {
                type: :object,
                required: %w[code message details],
                properties: {
                  code: { type: :string },
                  message: { type: :string },
                  details: {
                    type: :array,
                    items: {
                      type: :object,
                      required: %w[field message],
                      properties: { field: { type: :string }, message: { type: :string } }
                    }
                  }
                }
              }
            }
          }
        }
      },
      security: [ { bearer_auth: [] } ]
    }
  }

  config.openapi_format = :yaml
  # A response that does not match its declared schema fails the example rather than documenting a lie.
  config.openapi_strict_schema_validation = true
end
