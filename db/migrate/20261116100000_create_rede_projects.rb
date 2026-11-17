class CreateRedeProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :rede_projects do |t|
      t.references :account, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true, index: { unique: true }
      t.string :name, null: false
      t.string :slug, null: false
      t.string :color, null: false
      t.integer :status, null: false, default: 0
      t.datetime :closed_at

      t.timestamps
    end

    add_index :rede_projects, [:account_id, :slug], unique: true
  end
end
