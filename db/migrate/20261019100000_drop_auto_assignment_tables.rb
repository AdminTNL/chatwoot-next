class DropAutoAssignmentTables < ActiveRecord::Migration[7.0]
  def up
    drop_table :inbox_capacity_limits, if_exists: true
    drop_table :inbox_assignment_policies, if_exists: true
    drop_table :agent_capacity_policies, if_exists: true
    drop_table :assignment_policies, if_exists: true
    drop_table :inbox_members, if_exists: true
  end

  def down
    create_inbox_members
    create_assignment_policies
    create_agent_capacity_policies
    create_inbox_assignment_policies
    create_inbox_capacity_limits
  end

  private

  def create_inbox_members
    create_table :inbox_members, id: :serial, if_not_exists: true do |t|
      t.integer :user_id, null: false
      t.integer :inbox_id, null: false
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.index [:inbox_id, :user_id], name: 'index_inbox_members_on_inbox_id_and_user_id', unique: true
      t.index [:inbox_id], name: 'index_inbox_members_on_inbox_id'
    end
  end

  def create_assignment_policies
    create_table :assignment_policies, if_not_exists: true do |t|
      t.bigint :account_id, null: false
      t.string :name, limit: 255, null: false
      t.text :description
      t.integer :assignment_order, default: 0, null: false
      t.integer :conversation_priority, default: 0, null: false
      t.integer :fair_distribution_limit, default: 100, null: false
      t.integer :fair_distribution_window, default: 3600, null: false
      t.boolean :enabled, default: true, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.integer :exclude_older_than_hours, default: 168
      t.index [:account_id, :name], name: 'index_assignment_policies_on_account_id_and_name', unique: true
      t.index [:account_id], name: 'index_assignment_policies_on_account_id'
      t.index [:enabled], name: 'index_assignment_policies_on_enabled'
    end
  end

  def create_agent_capacity_policies
    create_table :agent_capacity_policies, if_not_exists: true do |t|
      t.bigint :account_id, null: false
      t.string :name, limit: 255, null: false
      t.text :description
      t.jsonb :exclusion_rules, default: {}, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index [:account_id], name: 'index_agent_capacity_policies_on_account_id'
    end
  end

  def create_inbox_assignment_policies
    create_table :inbox_assignment_policies, if_not_exists: true do |t|
      t.bigint :inbox_id, null: false
      t.bigint :assignment_policy_id, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index [:assignment_policy_id], name: 'index_inbox_assignment_policies_on_assignment_policy_id'
      t.index [:inbox_id], name: 'index_inbox_assignment_policies_on_inbox_id', unique: true
    end
  end

  def create_inbox_capacity_limits
    create_table :inbox_capacity_limits, if_not_exists: true do |t|
      t.bigint :agent_capacity_policy_id, null: false
      t.bigint :inbox_id, null: false
      t.integer :conversation_limit, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.index [:agent_capacity_policy_id, :inbox_id], name: 'idx_on_agent_capacity_policy_id_inbox_id_71c7ec4caf', unique: true
      t.index [:agent_capacity_policy_id], name: 'index_inbox_capacity_limits_on_agent_capacity_policy_id'
      t.index [:inbox_id], name: 'index_inbox_capacity_limits_on_inbox_id'
    end
  end
end
