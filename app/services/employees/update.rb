module Employees
  class Update
    def self.call(employee, attributes)
      employee.update!(attributes)
      employee
    end
  end
end
