class AuditSerializer
  def initialize(audit)
    @audit = audit
  end

  def as_json(*)
    {
      id: @audit.id,
      action: @audit.action,
      auditable_type: @audit.auditable_type.underscore,
      auditable_id: @audit.auditable_id,
      audited_changes: @audit.audited_changes,
      user: @audit.user && UserSerializer.new(@audit.user).as_json,
      created_at: @audit.created_at
    }
  end
end
