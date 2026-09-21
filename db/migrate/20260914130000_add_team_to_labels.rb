class AddTeamToLabels < ActiveRecord::Migration[7.0]
  def change
    add_reference :labels, :team, null: true, foreign_key: true, index: true
  end
end
