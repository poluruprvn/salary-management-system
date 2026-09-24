class UnknownSortKey < InvalidParameter
  def initialize(key)
    # The key is the subject of the sentence, so the default "sort <key> is not..." reads wrong.
    detail = "#{key} is not a sortable key"
    super(:sort, detail, detail)
  end
end
