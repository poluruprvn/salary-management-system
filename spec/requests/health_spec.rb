require 'swagger_helper'

RSpec.describe "Health" do
  let(:pool) { ActiveRecord::Base.connection_pool }

  checks = {
    status: { type: :string, enum: %w[ok unavailable] },
    database: { type: :string, enum: %w[ok unreachable] }
  }
  liveness = { type: :object, required: %w[status database], properties: checks }
  readiness = {
    type: :object,
    required: %w[status database migrations],
    properties: checks.merge(migrations: { type: :string, enum: %w[ok pending unknown] })
  }

  def database_down
    allow(pool).to receive(:with_connection).and_raise(ActiveRecord::ConnectionNotEstablished, "connection refused")
  end

  path "/healthz" do
    get "Liveness: the process is up and Postgres answers" do
      tags "Health"
      produces "application/json"
      security []

      response "200", "healthy" do
        schema liveness
        run_test! do |response|
          expect(response.parsed_body).to eq("status" => "ok", "database" => "ok")
        end
      end

      response "503", "Postgres did not answer" do
        schema liveness
        before { database_down }
        run_test! do |response|
          expect(response.parsed_body).to eq("status" => "unavailable", "database" => "unreachable")
        end
      end
    end
  end

  path "/readyz" do
    get "Readiness: liveness plus no pending migrations" do
      tags "Health"
      produces "application/json"
      security []

      response "200", "ready" do
        schema readiness
        run_test! do |response|
          expect(response.parsed_body).to eq("status" => "ok", "database" => "ok", "migrations" => "ok")
        end
      end

      response "503", "a migration is pending, or Postgres did not answer" do
        schema readiness
        before do
          allow(pool).to receive(:migration_context).and_return(
            instance_double(ActiveRecord::MigrationContext, needs_migration?: true)
          )
        end
        run_test! do |response|
          expect(response.parsed_body).to eq("status" => "unavailable", "database" => "ok", "migrations" => "pending")
        end
      end
    end
  end

  it "does not claim the migrations are current when it cannot reach Postgres" do
    database_down

    get "/readyz"

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq("status" => "unavailable", "database" => "unreachable", "migrations" => "unknown")
  end
end
