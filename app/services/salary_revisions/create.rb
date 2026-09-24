module SalaryRevisions
  class Create
    Change = Data.define(:revision, :previous)

    # The previous revision comes back with the new one, so the form can show the raise without a
    # second request. One transaction, so a failed read does not leave the insert behind.
    def self.call(employee, attributes)
      SalaryRevision.transaction do
        revision = employee.salary_revisions.create!(attributes)
        previous = employee.salary_revisions.live
          .where(effective_date: ...revision.effective_date)
          .order(effective_date: :desc)
          .first

        Change.new(revision: revision, previous: previous)
      end
    end
  end
end
