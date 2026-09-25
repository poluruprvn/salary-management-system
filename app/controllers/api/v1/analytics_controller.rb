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

      def cohorts
        render json: {
          as_of: as_of,
          data: Employee.cohorts(as_of: as_of).map do |row|
            {
              level: { id: row.level_id, name: row.level_name },
              country: { id: row.country_id, name: row.country_name },
              **row.slice(:headcount, :evaluated, :p25_cents, :p50_cents, :p75_cents, :lower_fence_cents, :upper_fence_cents).symbolize_keys,
              outliers_below: (row.outliers_below if row.evaluated),
              outliers_above: (row.outliers_above if row.evaluated),
              reason: unevaluated_reason(row)
            }
          end
        }
      end

      def outliers
        refuse_filters(:q, :status, :title)
        rows = Employee.outliers(as_of: as_of, filters: id_filter_params, direction: params[:direction])
        page = paginate(rows)

        render json: {
          as_of: as_of,
          data: page.records.map do |row|
            {
              id: row.id,
              name: row.name,
              department: { id: row.department_id, name: row.department_name },
              level: { id: row.level_id, name: row.level_name },
              country: { id: row.country_id, name: row.country_name },
              **row.slice(:amount_cents, :cohort_median_cents, :cohort_headcount, :direction, :distance_pct).symbolize_keys
            }
          end,
          pagination: page.metadata
        }
      end

      private
        # Status is always active here, and a free text search makes a population nobody can name.
        # A filter that is ignored instead would return everyone as if it had matched.
        def refuse_filters(*names)
          names.each do |name|
            raise InvalidParameter.new(name, "is not a filter here") if params.key?(name)
          end
        end

        def distribution_filters
          refuse_filters(:q, :status)
          raise InvalidParameter.new(:title, "must be a single value") unless params[:title].nil? || params[:title].is_a?(String)

          params.permit(:title).merge(id_filter_params)
        end

        def unevaluated_reason(row)
          return if row.evaluated

          row.headcount < Employee::MIN_COHORT ? "fewer than #{Employee::MIN_COHORT} people" : "p25 and p75 are equal"
        end

        def amounts(row)
          row.slice(:headcount, :salaried, :gross_cents, :loaded_cents).symbolize_keys
        end
    end
  end
end
