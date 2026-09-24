module Api
  module V1
    class BaseController < ApplicationController
      abstract!

      include ErrorHandling
      include Authentication
      include Pagination

      ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/

      private
        # Resolved once per request, so the filter, the salary join and the echoed date all agree.
        def as_of
          @as_of ||=
            if params[:as_of].blank?
              Date.current
            else
              iso_date(params[:as_of]) || raise(InvalidParameter.new(:as_of, "must be a date as YYYY-MM-DD"))
            end
        end

        # Date.iso8601 alone also accepts week dates, datetimes, and years past what Postgres stores.
        def iso_date(raw)
          Date.iso8601(raw) if raw.is_a?(String) && ISO_DATE.match?(raw)
        rescue Date::Error
          nil
        end
    end
  end
end
