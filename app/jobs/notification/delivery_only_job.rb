class Notification::DeliveryOnlyJob < ApplicationJob
  queue_as :default

  # Entrega push/e-mail sem gravar a notificação em `notifications`.
  def perform(user_id:, account_id:, conversation_id:, notification_type:)
    user = User.find_by(id: user_id)
    account = Account.find_by(id: account_id)
    conversation = account&.conversations&.find_by(id: conversation_id)
    return if user.blank? || account.blank? || conversation.blank?

    notification = Notification.new(
      user: user, account: account, primary_actor: conversation,
      notification_type: notification_type, secondary_actor: nil, last_activity_at: Time.zone.now
    )

    Notification::PushNotificationService.new(notification: notification).perform
    Notification::EmailNotificationService.new(notification: notification).perform if email_enabled?(user, account, notification_type)
  end

  private

  def email_enabled?(user, account, notification_type)
    setting = user.notification_settings.find_by(account_id: account.id)
    setting.present? && setting.public_send("email_#{notification_type}?")
  end
end
