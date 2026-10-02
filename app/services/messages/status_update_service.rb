class Messages::StatusUpdateService
  attr_reader :message, :status, :external_error

  def initialize(message, status, external_error = nil, force: false)
    @message = message
    @status = status
    @external_error = external_error
    @force = force
  end

  def perform
    return false unless valid_status_transition?

    update_message_status
  end

  private

  def update_message_status
    # Update status and set external_error only when failed
    message.update!(
      status: status,
      external_error: (status == 'failed' ? external_error : nil)
    )
  end

  def valid_status_transition?
    return true if @force

    Messages::StatusTransition.allowed?(from: message.status, to: status)
  end
end
