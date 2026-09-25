module Api
  module V1
    class AnalyticsController < BaseController
      def run_rate
        group_by = params[:group_by].presence || "department"
        rows = Employee.run_rate(as_of: as_of, group_by: group_by).to_a
        totals, groups = rows.partition(&:is_total)
        names = Employee.reflect_on_association(group_by).klass.where(id: groups.map(&:group_id)).pluck(:id, :name).to_h

        render json: {
          as_of: as_of,
          group_by: group_by,
          data: groups.map { |row| { group: { id: row.group_id, name: names[row.group_id] }, **amounts(row) } },
          totals: amounts(totals.sole)
        }
      end

      private
        def amounts(row)
          row.slice(:headcount, :salaried, :gross_cents, :loaded_cents).symbolize_keys
        end
    end
  end
end
