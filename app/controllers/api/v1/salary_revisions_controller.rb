module Api
  module V1
    class SalaryRevisionsController < BaseController
      def index
        render json: { data: SalaryRevision.history_for(employee).map { |revision| SalaryHistorySerializer.new(revision) } }
      end

      def create
        render json: SalaryChangeSerializer.new(SalaryRevisions::Create.call(employee, revision_params)), status: :created
      end

      def update
        render json: SalaryRevisionSerializer.new(SalaryRevisions::Update.call(revision, revision_params))
      end

      # Voids rather than deletes, and a second call is a no-op.
      def destroy
        SalaryRevisions::Void.call(revision)
        head :no_content
      end

      private
        def employee
          @employee ||= Employee.find(params[:employee_id])
        end

        # Voided revisions are found too: the model refuses to edit one, and voiding twice is harmless.
        def revision
          employee.salary_revisions.find(params[:id])
        end

        def revision_params
          params.permit(:amount_cents, :effective_date, :reason, :note).to_h
        end
    end
  end
end
