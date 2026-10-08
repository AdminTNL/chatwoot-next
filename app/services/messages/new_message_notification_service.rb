class Messages::NewMessageNotificationService
  pattr_initialize [:message!]

  def perform
    return unless message.notifiable?

    notify_participating_users
  end

  private

  delegate :conversation, :sender, :account, to: :message

  def notify_participating_users
    participating_users = conversation.conversation_participants.map(&:user)
    participating_users -= [sender] if sender.is_a?(User)

    participating_users.uniq.each do |participant|
      next if already_notified?(participant)

      NotificationBuilder.new(
        notification_type: 'participating_conversation_new_message',
        user: participant,
        account: account,
        primary_actor: message.conversation,
        secondary_actor: message
      ).perform
    end
  end

  # The user could already have been notified via a mention
  # So we don't need to notify them again
  def already_notified?(user)
    conversation.notifications.exists?(user: user, secondary_actor: message)
  end
end
