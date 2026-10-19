class RemoveAutoAssignmentColumns < ActiveRecord::Migration[7.0]
  def change
    remove_index :account_users, :agent_capacity_policy_id, name: 'index_account_users_on_agent_capacity_policy_id'
    remove_column :account_users, :agent_capacity_policy_id, :bigint
    remove_column :inboxes, :enable_auto_assignment, :boolean, default: true
    remove_column :inboxes, :auto_assignment_config, :jsonb, default: {}
    remove_column :teams, :allow_auto_assign, :boolean, default: true
  end
end
