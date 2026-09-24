class CreateLevels < ActiveRecord::Migration[8.1]
  def change
    create_table :levels, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.integer :rank, null: false

      t.timestamps
    end

    # Case insensitive so L2 and l2 cannot both exist.
    add_index :levels, "lower(code)", unique: true, name: "index_levels_on_lower_code"
    add_index :levels, :rank, unique: true
  end
end
