class CreateLabelGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :label_groups do |t|
      t.string :name, null: false
      t.references :account, null: false, foreign_key: true, index: true
      t.references :team, null: false, foreign_key: true, index: true

      t.timestamps
    end

    add_index :label_groups, [:team_id, :name], unique: true
  end
end
