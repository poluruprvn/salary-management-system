class DepartmentSerializer
  def initialize(department)
    @department = department
  end

  def as_json(*)
    { id: @department.id, name: @department.name }
  end
end
