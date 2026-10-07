class Notification::AccessCleanupJob < ApplicationJob
  queue_as :low

  def perform(account_id, user_ids)
    account = Account.find_by(id: account_id)
    return if account.blank?

    Notifications::AccessCleanupService.new(account: account, user_ids: user_ids).perform
  end
end
