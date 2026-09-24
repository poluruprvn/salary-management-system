class CreateCountries < ActiveRecord::Migration[8.1]
  def change
    create_table :countries, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :code, limit: 2, null: false
      t.string :name, null: false
      t.decimal :employer_cost_multiplier, precision: 6, scale: 4, null: false, default: 1.0

      t.timestamps
    end

    add_index :countries, :code, unique: true
    add_check_constraint :countries, "code ~ '^[A-Z]{2}$'", name: "countries_code_format"
    add_check_constraint :countries, "employer_cost_multiplier > 0", name: "countries_employer_cost_multiplier_positive"
  end
end
