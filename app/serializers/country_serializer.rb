class CountrySerializer
  def initialize(country)
    @country = country
  end

  def as_json(*)
    { id: @country.id, code: @country.code, name: @country.name }
  end
end
