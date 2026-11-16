class CreateRedeRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :rede_roles do |t|
      t.references :account, null: false, foreign_key: true
      t.string :key, null: false
      t.string :name, null: false

      t.timestamps
    end

    add_index :rede_roles, [:account_id, :key], unique: true
  end
end
