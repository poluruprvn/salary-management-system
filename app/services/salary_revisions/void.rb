module SalaryRevisions
  class Void
    # A second void keeps the first timestamp, which is when the revision actually left the live set.
    def self.call(revision)
      revision.update!(voided_at: Time.current) unless revision.voided_at?
      revision
    end
  end
end
