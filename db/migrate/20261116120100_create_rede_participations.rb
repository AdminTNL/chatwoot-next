class CreateRedeParticipations < ActiveRecord::Migration[7.1]
  def change
    create_table :rede_participations do |t|
      t.references :account, null: false, foreign_key: true
      # contacts.id e users.id são integer, não bigint
      t.references :contact, null: false, type: :integer, foreign_key: true, index: false
      t.references :project, null: false, foreign_key: { to_table: :rede_projects }, index: false
      t.references :responsible_user, type: :integer, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :referred_by_contact, type: :integer, foreign_key: { to_table: :contacts, on_delete: :nullify }
      t.string :referred_by_text
      t.text :next_step
      t.integer :origin, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :joined_at, null: false

      t.timestamps
    end

    add_index :rede_participations, [:contact_id, :project_id], unique: true
    add_index :rede_participations, [:project_id, :status]
  end
end
