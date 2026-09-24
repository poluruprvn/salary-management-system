class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.references :country, type: :uuid, null: false, foreign_key: true
      t.references :department, type: :uuid, null: false, foreign_key: true
      t.references :level, type: :uuid, null: false, foreign_key: true
      t.string :title, null: false
      t.date :hire_date, null: false
      t.date :exit_date

      t.timestamps
    end

    # insert_all and upsert_all skip the model downcase, so uniqueness is over lower(email).
    add_index :employees, "lower(email)", unique: true, name: "index_employees_on_lower_email"
    add_index :employees, :title
    add_index :employees, :hire_date
    add_index :employees, :exit_date

    # A backdated hire or exit does not move created_at, so the freeze reads updated_at here too.
    add_index :employees, :updated_at

    # Collation on the musl image is byte order, so ORDER BY name puts every capital first.
    # The id tiebreak keeps offset pagination stable across duplicate names.
    add_index :employees, "lower(name), id", name: "index_employees_on_lower_name_and_id"

    add_check_constraint :employees, "exit_date IS NULL OR exit_date >= hire_date", name: "employees_exit_date_not_before_hire_date"
  end
end
