class CreateRedeQualityResolutions < ActiveRecord::Migration[7.1]
  def change
    create_table :rede_quality_resolutions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: { to_table: :rede_projects }, index: false
      t.integer :kind, null: false
      # Sem FK: no merge o contato absorvido deixa de existir, mas o par resolvido continua registrado.
      t.integer :contact_a_id, null: false
      t.integer :contact_b_id, null: false
      t.integer :resolved_by_user_id

      t.timestamps
    end

    add_index :rede_quality_resolutions, [:project_id, :created_at], name: 'index_rede_quality_resolutions_on_project_and_created_at'
    add_index :rede_quality_resolutions, [:project_id, :contact_a_id, :contact_b_id], unique: true, where: 'kind = 1',
                                                                                      name: 'index_rede_quality_resolutions_dismissed_pair'
  end
end
