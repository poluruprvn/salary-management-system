class HealthController < ApplicationController
  def show
    render_checks database: database
  end

  def ready
    render_checks database: database, migrations: migrations
  end

  private
    def render_checks(checks)
      healthy = checks.values.all?("ok")
      render json: { status: healthy ? "ok" : "unavailable", **checks },
             status: healthy ? :ok : :service_unavailable
    end

    def database
      ActiveRecord::Base.connection_pool.with_connection { |connection| connection.select_value("SELECT 1") }
      "ok"
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error { "Health check: database unreachable: #{e.class}: #{e.message}" }
      "unreachable"
    end

    # Not ActiveRecord::Migration.check_all_pending!, which re-establishes the shared pool and would
    # drop the connections of requests in flight on other threads.
    def migrations
      ActiveRecord::Base.connection_pool.migration_context.needs_migration? ? "pending" : "ok"
    rescue ActiveRecord::ActiveRecordError
      "unknown"
    end
end
