module Api
  module V1
    class CountriesController < BaseController
      def index
        render json: { data: Country.by_name.map { |country| CountrySerializer.new(country) } }
      end

      # Code and name are the closed set's identity, so only the multiplier is editable.
      def update
        multiplier = params.permit(:employer_cost_multiplier).require(:employer_cost_multiplier)
        country = Countries::Update.call(Country.find(params[:id]), employer_cost_multiplier: multiplier)
        render json: CountrySerializer.new(country)
      end
    end
  end
end
