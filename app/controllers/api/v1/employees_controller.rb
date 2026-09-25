module Api
  module V1
    class EmployeesController < BaseController
      # Parsed up front, so a bad as_of is refused before a write commits, not after.
      before_action :as_of, only: [ :create, :update ]

      def index
        employees = Employee.filtered(filter_params, as_of: as_of)
        # The count runs on the filters alone and never pays for the salary join.
        page = paginate(employees.with_salary_as_of(as_of).sorted_by(params[:sort]).preload(:country, :department, :level),
                        total: employees.count)

        render json: { data: page.records.map { |employee| serialize(employee) }, pagination: page.metadata }
      end

      def show
        render json: serialize(Employee.find(params[:id]))
      end

      def create
        render json: serialize(Employees::Create.call(employee_params)), status: :created
      end

      def update
        render json: serialize(Employees::Update.call(Employee.find(params[:id]), employee_params))
      end

      private
        def serialize(employee)
          EmployeeSerializer.new(employee, as_of: as_of)
        end

        # permit drops a value of the wrong shape in silence, so status[]=active would filter nothing.
        # The single value filters refuse an array, and the id filters take one id or many.
        def filter_params
          %i[q title status].each do |name|
            raise InvalidParameter.new(name, "must be a single value") unless params[name].nil? || params[name].is_a?(String)
          end

          params.permit(:q, :title, :status).merge(id_filter_params)
        end

        def employee_params
          params.permit(:name, :email, :title, :hire_date, :exit_date, :country_id, :department_id, :level_id).to_h
        end
    end
  end
end
