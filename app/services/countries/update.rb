module Countries
  class Update
    def self.call(country, attributes)
      country.update!(attributes)
      country
    end
  end
end
