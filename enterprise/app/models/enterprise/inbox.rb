module Enterprise::Inbox
  def active_bot?
    super || captain_active?
  end

  def captain_active?
    captain_assistant.present? && more_responses?
  end

  private

  def more_responses?
    account.usage_limits[:captain][:responses][:current_available].positive?
  end
end
