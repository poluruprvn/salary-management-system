module Employees
  class Create
    def self.call(attributes)
      Employee.create!(attributes)
    end
  end
end
