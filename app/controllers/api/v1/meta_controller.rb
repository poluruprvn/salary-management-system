module Api
  module V1
    class MetaController < BaseController
      # Every amount is stored in hundredths: amount_cents.
      MINOR_UNIT = 2

      def show
        render json: {
          base_currency: ENV.fetch("BASE_CURRENCY", "USD"),
          minor_unit: MINOR_UNIT,
          today: Date.current,
          employee_statuses: Employee::STATUSES,
          salary_revision_reasons: SalaryRevision::REASONS
        }
      end
    end
  end
end
