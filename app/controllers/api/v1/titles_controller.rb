module Api
  module V1
    class TitlesController < BaseController
      # A typeahead, not a report: it truncates instead of paginating.
      LIMIT = 20

      def index
        titles = Employee.title_counts(params[:q]).limit(LIMIT)

        render json: { data: titles.map { |row| { title: row.title, employee_count: row.employee_count } } }
      end
    end
  end
end
