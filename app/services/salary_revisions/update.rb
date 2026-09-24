module SalaryRevisions
  class Update
    def self.call(revision, attributes)
      revision.update!(attributes)
      revision
    end
  end
end
