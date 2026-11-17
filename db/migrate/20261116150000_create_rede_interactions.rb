class CreateRedeInteractions < ActiveRecord::Migration[7.1]
  def change
    create_table :rede_interactions do |t|
      t.references :account, null: false, foreign_key: true
      # contacts.id e users.id são integer, não bigint
      t.references :contact, null: false, type: :integer, foreign_key: true, index: false
      t.references :project, null: false, foreign_key: { to_table: :rede_projects }, index: false
      t.references :front, foreign_key: { to_table: :rede_fronts }
      t.references :author_user, type: :integer, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :kind, null: false
      t.boolean :answered # rubocop:disable Rails/ThreeStateBooleanColumn -- nulo em nota
      t.text :summary, null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :rede_interactions, [:contact_id, :project_id, :occurred_at], name: 'index_rede_interactions_on_contact_project_occurred_at'
  end
end
