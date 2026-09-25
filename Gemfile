source "https://rubygems.org"

gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "pg", "~> 1.1"
# json 3 dropped the positional options hash from JSON.parse, which is how
# ActiveSupport::JSON.decode still calls it. Every jsonb read raises ArgumentError.
gem "json", "~> 2.21"
gem "puma", ">= 5.0"
gem "rack-cors"

gem "audited"
gem "bcrypt", "~> 3.1.7"
gem "jwt"
gem "lograge"
# The seeds fill the demo deploy with invented employees.
gem "faker"

gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "dotenv-rails"

  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "annotaterb", require: false
  gem "kamal", require: false
  gem "rswag-api"
  gem "rswag-ui"
end

group :test do
  gem "rswag-specs"
  gem "shoulda-matchers"
end
