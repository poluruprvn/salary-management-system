Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new
  config.lograge.custom_options = ->(event) { event.payload.slice(:request_id, :user_id) }
end
