class NotificationBuilder
  pattr_initialize [:notification_type!, :user!, :account!, :primary_actor!, :secondary_actor]

  def perform
    build_notification
  end

  private

  def current_user
    Current.user
  end

  def user_subscribed_to_notification?
    notification_setting = user.notification_settings.find_by(account_id: account.id)
    # added for the case where an assignee might be removed from the account but remains in conversation
    return false if notification_setting.blank?

    return true if notification_setting.public_send("email_#{notification_type}?")
    return true if notification_setting.public_send("push_#{notification_type}?")

    false
  end

  def build_notification
    return unless deliverable?

    return enqueue_delivery_only if conversation_creation?

    user.notifications.create!(
      notification_type: notification_type,
      account: account,
      primary_actor: primary_actor,
      # secondary_actor is secondary_actor if present, else current_user
      secondary_actor: secondary_actor || current_user
    )
  end

  def deliverable?
    # Create conversation_creation notification only if user is subscribed to it
    return false if conversation_creation? && !user_subscribed_to_notification?
    # skip notifications for blocked conversations except for user mentions
    return false if primary_actor.contact.blocked? && notification_type != 'conversation_mention'

    # respect conversation access (inbox/team membership and custom-role permissions)
    user_can_access_conversation?
  end

  def conversation_creation?
    notification_type == 'conversation_creation'
  end

  # Conversa nova não é gravada em notifications: vira só entrega push/e-mail.
  def enqueue_delivery_only
    Notification::DeliveryOnlyJob.perform_later(
      user_id: user.id,
      account_id: account.id,
      conversation_id: primary_actor.id,
      notification_type: notification_type
    )
  end

  def user_can_access_conversation?
    conversation = primary_actor.is_a?(Conversation) ? primary_actor : primary_actor.try(:conversation)
    return true if conversation.blank?

    account_user = AccountUser.find_by(account_id: account.id, user_id: user.id)
    return false if account_user.blank?

    ConversationPolicy.new(
      { user: user, account: account, account_user: account_user },
      conversation
    ).show?
  end
end
