class CreateRedeAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :rede_assignments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :participation, null: false, foreign_key: { to_table: :rede_participations }, index: false
      t.references :front, foreign_key: { to_table: :rede_fronts }
      t.references :role, foreign_key: { to_table: :rede_roles }
      t.references :superior_contact, type: :integer, foreign_key: { to_table: :contacts, on_delete: :nullify }
      t.integer :status, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :ended_at

      t.timestamps
    end

    # No máximo uma atuação ativa por participação e frente; "sem frente" conta como uma frente (COALESCE).
    add_index :rede_assignments, 'participation_id, COALESCE(front_id, 0)', unique: true, where: 'status = 0',
                                                                            name: 'index_rede_assignments_on_active_participation_and_front'
    add_index :rede_assignments, [:participation_id, :status]
  end
end
