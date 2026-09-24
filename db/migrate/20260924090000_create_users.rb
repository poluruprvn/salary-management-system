class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name, null: false

      t.timestamps
    end

    # Sign in is case insensitive, so two accounts must not differ only by case.
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
  end
end
