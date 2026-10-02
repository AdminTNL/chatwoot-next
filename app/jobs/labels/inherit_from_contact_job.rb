class Labels::InheritFromContactJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:)
    Labels::ContactInheritanceService.new(conversation_id: conversation_id).perform
  end
end
