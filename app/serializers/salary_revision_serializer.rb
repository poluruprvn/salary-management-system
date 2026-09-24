class SalaryRevisionSerializer
  def initialize(revision)
    @revision = revision
  end

  def as_json(*)
    {
      id: @revision.id,
      amount_cents: @revision.amount_cents,
      effective_date: @revision.effective_date,
      reason: @revision.reason,
      note: @revision.note,
      voided_at: @revision.voided_at
    }
  end
end
