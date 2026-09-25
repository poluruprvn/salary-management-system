class CountrySerializer
  def initialize(country)
    @country = country
  end

  def as_json(*)
    { id: @country.id, code: @country.code, name: @country.name, employer_cost_multiplier: @country.employer_cost_multiplier }
  end
end
