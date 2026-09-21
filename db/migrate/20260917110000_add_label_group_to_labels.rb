class AddLabelGroupToLabels < ActiveRecord::Migration[7.0]
  def change
    add_reference :labels, :label_group, null: true, foreign_key: true, index: true
  end
end
