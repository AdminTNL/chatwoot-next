class Notifications::AccessCleanupService
  pattr_initialize [:account!, :user_ids!]

  def perform
    Array(user_ids).each { |user_id| cleanup_user(user_id) }
  end

  private

  def cleanup_user(user_id)
    account_user = AccountUser.find_by(account_id: account.id, user_id: user_id)
    return if account_user&.administrator?

    scope = account.notifications.where(user_id: user_id, primary_actor_type: 'Conversation')
    scope = scope.where.not(primary_actor_id: accessible_conversation_ids(user_id)) if account_user.present?
    scope.find_each(&:destroy)
  end

  def accessible_conversation_ids(user_id)
    user = User.find(user_id)
    team_ids = user.teams.where(account_id: account.id).select(:id)
    inbox_ids = user.accessible_inboxes(account).select(:id)
    account.conversations.where(team_id: team_ids).or(account.conversations.where(inbox_id: inbox_ids)).select(:id)
  end
end
