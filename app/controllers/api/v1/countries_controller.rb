module Api
  module V1
    class CountriesController < BaseController
      def index
        render json: { data: Country.by_name.map { |country| CountrySerializer.new(country) } }
      end

      # Code and name are the closed set's identity, so only the multiplier is editable.
      def update
        country = Countries::Update.call(Country.find(params[:id]), params.permit(:employer_cost_multiplier).to_h)
        render json: CountrySerializer.new(country)
      end
    end
  end
end
