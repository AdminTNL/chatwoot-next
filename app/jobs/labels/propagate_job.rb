class Labels::PropagateJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:, added_labels:, removed_labels:)
    Labels::PropagationService.new(
      conversation_id: conversation_id,
      added_labels: added_labels,
      removed_labels: removed_labels
    ).perform
  end
end
