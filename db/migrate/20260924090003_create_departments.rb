class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :name, null: false

      t.timestamps
    end

    # Case insensitive so a spreadsheet's "engineering" cannot land as a second row.
    add_index :departments, "lower(name)", unique: true, name: "index_departments_on_lower_name"
  end
end
