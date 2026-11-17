class CreateRedeFronts < ActiveRecord::Migration[7.1]
  def change
    create_table :rede_fronts do |t|
      t.references :account, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: { to_table: :rede_projects }
      t.string :name, null: false
      t.uuid :public_id, null: false, default: -> { 'gen_random_uuid()' }
      t.boolean :has_temperature, null: false, default: true
      t.integer :status, null: false, default: 0
      t.datetime :closed_at

      t.timestamps
    end

    add_index :rede_fronts, :public_id, unique: true
    add_index :rede_fronts, 'project_id, lower(name)', unique: true, name: 'index_rede_fronts_on_project_id_and_lower_name'
  end
end
