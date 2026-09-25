module Api
  module V1
    class AnalyticsController < BaseController
      def run_rate
        group_by = params[:group_by].presence || "department"
        totals, groups = Analytics::RunRate.call(as_of: as_of, group_by: group_by).to_a.partition(&:is_total)

        render json: {
          as_of: as_of,
          group_by: group_by,
          data: groups.map { |row| { group: { id: row.group_id, name: row.group_name }, **amounts(row) } },
          totals: amounts(totals.sole)
        }
      end

      def distribution
        group_by = params[:group_by].presence || "department"
        filters = distribution_filters
        summary = Analytics::Distribution.summary(as_of: as_of, group_by: group_by, filters: filters).take
        rows = Analytics::Distribution.call(as_of: as_of, group_by: group_by, filters: filters, sort: params[:sort])
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
          data: Analytics::Cohorts.call(as_of: as_of).map do |row|
            {
              level: { id: row.level_id, name: row.level_name },
              country: { id: row.country_id, name: row.country_name },
              **row.slice(:headcount, :evaluated, :p25_cents, :p50_cents, :p75_cents, :lower_fence_cents, :upper_fence_cents,
                          :outliers_below, :outliers_above, :reason).symbolize_keys
            }
          end
        }
      end

      def outliers
        refuse_filters(:q, :status, :title)
        rows = Analytics::Outliers.call(as_of: as_of, filters: id_filter_params, direction: params[:direction])
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

      def trend
        render json: {
          as_of: as_of,
          data: Analytics::Trend.call(as_of: as_of).map do |row|
            { date: row.date, **amounts(row), **row.slice(:hires, :exits, :raises, :raise_delta_cents).symbolize_keys }
          end
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

        def amounts(row)
          row.slice(:headcount, :salaried, :gross_cents, :loaded_cents).symbolize_keys
        end
    end
  end
end
