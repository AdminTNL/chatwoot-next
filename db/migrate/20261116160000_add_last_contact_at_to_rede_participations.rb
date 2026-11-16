class AddLastContactAtToRedeParticipations < ActiveRecord::Migration[7.1]
  def change
    add_column :rede_participations, :last_contact_at, :datetime
    add_index :rede_participations, [:project_id, :last_contact_at]
  end
end
