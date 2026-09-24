# rswag-api is a development-group gem and this file loads in every environment.
if defined?(Rswag::Api::Engine)
  Rswag::Api.configure do |c|
    c.openapi_root = Rails.root.join("swagger").to_s
  end
end
