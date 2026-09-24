class InvalidParameter < StandardError
  attr_reader :field, :detail

  def initialize(field, detail, message = "#{field} #{detail}")
    @field = field
    @detail = detail
    super(message)
  end
end
