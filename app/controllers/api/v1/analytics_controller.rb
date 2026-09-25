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

      def distribution
        group_by = params[:group_by].presence || "department"
        filters = distribution_filters
        summary = Employee.distribution_summary(as_of: as_of, group_by: group_by, filters: filters)
        rows = Employee.distribution(as_of: as_of, group_by: group_by, filters: filters, sort: params[:sort])
        page = paginate(rows, total: summary.groups)

        render json: {
          as_of: as_of,
          group_by: group_by,
          data: page.records.map do |row|
            { group: { id: row.group_id, name: row.group_name },
              **row.slice(:headcount, :min_cents, :p25_cents, :median_cents, :p75_cents, :max_cents).symbolize_keys }
          end,
          unsalaried: summary.unsalaried,
          pagination: page.metadata
        }
      end

      private
        # Status is always active here, and a free text search makes a population nobody can name.
        def distribution_filters
          %i[q status].each do |name|
            raise InvalidParameter.new(name, "is not a filter here") if params.key?(name)
          end
          raise InvalidParameter.new(:title, "must be a single value") unless params[:title].nil? || params[:title].is_a?(String)

          params.permit(:title).merge(id_filter_params)
        end

        def amounts(row)
          row.slice(:headcount, :salaried, :gross_cents, :loaded_cents).symbolize_keys
        end
    end
  end
end
