class CreateSalaryRevisions < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_revisions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :employee, type: :uuid, null: false, foreign_key: true
      t.bigint :amount_cents, null: false
      t.date :effective_date, null: false
      t.string :reason, null: false
      t.text :note
      t.datetime :voided_at

      t.timestamps
    end

    # Voiding is the only delete, so the uniqueness that matters is over live rows.
    add_index :salary_revisions, [ :employee_id, :effective_date ],
      unique: true, where: "voided_at IS NULL",
      name: "index_salary_revisions_on_employee_id_and_live_effective_date"

    # Neither a void nor a correction moves created_at, so the deferred register freeze reads updated_at.
    add_index :salary_revisions, :updated_at

    add_check_constraint :salary_revisions, "amount_cents > 0", name: "salary_revisions_amount_cents_positive"
  end
end
