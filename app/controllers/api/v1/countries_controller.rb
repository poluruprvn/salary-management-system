module Api
  module V1
    class CountriesController < BaseController
      def index
        render json: { data: Country.by_name.map { |country| CountrySerializer.new(country) } }
      end
    end
  end
end
