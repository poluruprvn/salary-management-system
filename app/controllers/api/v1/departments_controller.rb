module Api
  module V1
    class DepartmentsController < BaseController
      def index
        render json: { data: Department.by_name.map { |department| DepartmentSerializer.new(department) } }
      end
    end
  end
end
