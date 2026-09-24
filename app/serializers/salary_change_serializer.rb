# The previous revision rides along, so the form can show the raise without a second request.
class SalaryChangeSerializer < SalaryRevisionSerializer
  def initialize(change)
    super(change.revision)
    @previous = change.previous
  end

  def as_json(*)
    super.merge(previous_amount_cents: @previous&.amount_cents, previous_effective_date: @previous&.effective_date)
  end
end
