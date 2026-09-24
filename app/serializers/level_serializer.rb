class LevelSerializer
  def initialize(level)
    @level = level
  end

  def as_json(*)
    { id: @level.id, code: @level.code, name: @level.name, rank: @level.rank }
  end
end
