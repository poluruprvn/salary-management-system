module Api
  module V1
    class AuditsController < BaseController
      def index
        page = paginate(Employee.find(params[:employee_id]).audit_trail.preload(:user))

        render json: { data: page.records.map { |audit| AuditSerializer.new(audit) }, pagination: page.metadata }
      end
    end
  end
end
