module Pagination
  extend ActiveSupport::Concern

  InvalidPage = Class.new(InvalidParameter)

  Page = Data.define(:records, :metadata)

  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100

  private
    def paginate(relation, total: nil)
      per_page = [ positive_integer_param(:per_page, DEFAULT_PER_PAGE), MAX_PER_PAGE ].min
      page = positive_integer_param(:page, 1)
      # A bare count puts a custom select list inside COUNT(), which is invalid SQL. :all counts rows.
      total = (total || relation.count(:all)).to_i
      total_pages = (total / per_page.to_f).ceil

      metadata = {
        total: total,
        page: page,
        per_page: per_page,
        total_pages: total_pages,
        # Clamped so a page past the end still offers a link back to real data.
        prev_page: (page > 1 && total_pages.positive?) ? [ page - 1, total_pages ].min : nil,
        next_page: page < total_pages ? page + 1 : nil
      }.freeze
      set_pagination_headers(metadata)

      # Past the end there is nothing to fetch, and a big enough offset overflows bigint.
      records = page > total_pages ? relation.none : relation.limit(per_page).offset((page - 1) * per_page)

      Page.new(records: records, metadata: metadata)
    end

    def positive_integer_param(name, default)
      raw = params[name]
      return default if raw.blank?

      # Base 10 explicitly, or Integer("010") is 8 and the client silently gets another page.
      value = Integer(raw, 10, exception: false)
      raise InvalidPage.new(name, "must be a positive integer") if value.nil? || value < 1

      value
    end

    def set_pagination_headers(metadata)
      links = [ %(<#{page_url(1)}>; rel="first") ]
      links << %(<#{page_url(metadata[:prev_page])}>; rel="prev") if metadata[:prev_page]
      links << %(<#{page_url(metadata[:next_page])}>; rel="next") if metadata[:next_page]
      links << %(<#{page_url(metadata[:total_pages])}>; rel="last") if metadata[:total_pages].positive?

      response.headers["Link"] = links.join(", ")
      response.headers["X-Total-Count"] = metadata[:total].to_s
    end

    # Rewrites page on the current query, so the links stay on the same filtered view.
    def page_url(number)
      "#{request.base_url}#{request.path}?#{request.query_parameters.merge("page" => number).to_query}"
    end
end
