class InstallAudited < ActiveRecord::Migration[8.1]
  def change
    create_table :audits, id: :uuid, default: -> { "uuidv7()" } do |t|
      # The generator hardcodes auditable_id and associated_id as integer. Only user_id is an
      # option. Rails casts a UUID through to_i, so 01a0d30a-... stores as 1. Every row
      # collapses onto the same id and auditable resolves to nil.
      t.uuid :auditable_id, null: false
      t.string :auditable_type, null: false
      t.uuid :associated_id
      t.string :associated_type
      t.uuid :user_id
      t.string :user_type
      t.string :username
      t.string :action, null: false
      t.jsonb :audited_changes
      t.integer :version, default: 0, null: false
      t.string :comment
      t.string :remote_address
      t.string :request_uuid
      t.datetime :created_at, null: false
    end

    add_index :audits, [ :auditable_type, :auditable_id, :version ], name: "auditable_index"
    add_index :audits, [ :associated_type, :associated_id ], name: "associated_index"
    add_index :audits, [ :user_id, :user_type ], name: "user_index"
    add_index :audits, :request_uuid
    add_index :audits, :created_at
  end
end
