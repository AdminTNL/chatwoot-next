class CreateRedeEvaluations < ActiveRecord::Migration[7.1]
  def change
    create_table :rede_evaluations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :contact, type: :integer, null: false, foreign_key: true, index: false
      t.references :project, null: false, foreign_key: { to_table: :rede_projects }
      t.references :front, foreign_key: { to_table: :rede_fronts }
      t.references :author_user, type: :integer, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :dimension, null: false, default: 'temperatura'
      t.integer :level
      t.text :note
      t.datetime :evaluated_at, null: false

      t.timestamps
    end

    add_index :rede_evaluations, [:contact_id, :project_id, :front_id, :evaluated_at], name: 'index_rede_evaluations_on_context_and_evaluated_at'
  end
end
