# A row of SalaryRevision.history_for, which carries the amount in force before it.
class SalaryHistorySerializer < SalaryRevisionSerializer
  def as_json(*)
    super.merge(previous_amount_cents: @revision.previous_amount_cents)
  end
end
