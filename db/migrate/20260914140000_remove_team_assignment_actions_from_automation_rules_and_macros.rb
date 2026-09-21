class RemoveTeamAssignmentActionsFromAutomationRulesAndMacros < ActiveRecord::Migration[7.1]
  TEAM_ACTION_NAMES = %w[assign_team remove_assigned_team].freeze

  def up
    strip_team_actions_from(AutomationRule, deactivatable: true)
    strip_team_actions_from(Macro, deactivatable: false)
  end

  def down
    # no-op: the removed actions cannot be reconstructed, and records were
    # deactivated (not deleted), so there is nothing destructive to undo.
  end

  private

  def strip_team_actions_from(klass, deactivatable:)
    table_name = klass.table_name
    emptied_ids = []

    klass.reset_column_information
    klass.where("actions @> '[{\"action_name\": \"assign_team\"}]' OR actions @> '[{\"action_name\": \"remove_assigned_team\"}]'")
         .find_each do |record|
      original_actions = record.actions || []
      remaining_actions = original_actions.reject { |action| TEAM_ACTION_NAMES.include?(action['action_name']) }

      next if remaining_actions == original_actions

      update_attrs = { actions: remaining_actions }

      if remaining_actions.empty?
        emptied_ids << record.id
        update_attrs[:active] = false if deactivatable && klass.column_names.include?('active')
      end

      record.update_columns(update_attrs)
    end

    return if emptied_ids.empty?

    say "#{table_name}: #{emptied_ids.size} record(s) left with no actions after cleanup, marked inactive where possible: #{emptied_ids.join(', ')}"
  end
end
