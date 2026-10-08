class Notifications::ObsoleteCleanupService
  # conversation_assignment (2) e assigned_conversation_new_message (4) nas flags
  ASSIGNMENT_FLAGS_MASK = 6
  OBSOLETE_TYPES = [1, 2, 3].freeze

  def perform
    delete_obsolete_types
    delete_without_access
    clear_assignment_flags
  end

  private

  def delete_obsolete_types
    Notification.where(notification_type: OBSOLETE_TYPES).delete_all
  end

  def delete_without_access
    Notification.connection.execute(<<~SQL.squish)
      DELETE FROM notifications n
      USING conversations c
      WHERE n.primary_actor_type = 'Conversation'
        AND n.primary_actor_id = c.id
        AND NOT EXISTS (
          SELECT 1 FROM account_users au
          WHERE au.user_id = n.user_id AND au.account_id = n.account_id AND au.role = #{AccountUser.roles[:administrator]}
        )
        AND NOT EXISTS (
          SELECT 1 FROM team_members tm WHERE tm.user_id = n.user_id AND tm.team_id = c.team_id
        )
        AND NOT EXISTS (
          SELECT 1 FROM inbox_members im WHERE im.user_id = n.user_id AND im.inbox_id = c.inbox_id
        )
    SQL
  end

  def clear_assignment_flags
    NotificationSetting.update_all( # rubocop:disable Rails/SkipsModelValidations
      "push_flags = (push_flags & ~#{ASSIGNMENT_FLAGS_MASK}), email_flags = (email_flags & ~#{ASSIGNMENT_FLAGS_MASK})"
    )
  end
end
