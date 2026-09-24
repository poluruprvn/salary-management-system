# rswag-ui is a development-group gem and this file loads in every environment.
if defined?(Rswag::Ui::Engine)
  Rswag::Ui.configure do |c|
    c.swagger_endpoint "/api-docs/v1/openapi.yaml", "API V1 Docs"
  end
end
